package org.apache.iotdb.jarCode;

import java.io.IOException;
import java.io.PrintWriter;
import org.apache.iotdb.rpc.IoTDBConnectionException;
import org.apache.iotdb.rpc.StatementExecutionException;
import org.apache.iotdb.session.Session;
import org.apache.iotdb.session.SessionDataSet;
import org.apache.iotdb.session.SessionDataSet.DataIterator;
import org.apache.iotdb.tsfile.read.common.RowRecord;
import org.apache.thrift.TException;

public class QueryDataMultiSeries {

  // * (1) min_time(%s), max_time(%s), first_value(%s), last_value(%s), min_value(%s), max_value(%s)
  //       => Don't change the sequence of the above six aggregates!
  // * (2) group by ([tqs,tqe),IntervalLength) => Make sure (tqe-tqs) is divisible by
  // IntervalLength!
  // * (3) NOTE the time unit of interval. Update for different datasets!
  private static final String M4_LSM =
      "select min_time(%s), max_time(%s), first_value(%s), last_value(%s), min_value(%s), max_value(%s) "
          + "from %s "
          + "group by ([%d, %d), %d%s)"; // note the time precision unit is also parameterized

  private static final String MINMAX_LSM = "select min_value(%s), max_value(%s) " + "from %s "
      + "group by ([%d, %d), %d%s)"; // note the time precision unit is also parameterized

  private static final String M4_UDF = "select M4(%1$s,'tqs'='%3$d','tqe'='%4$d','w'='%5$d') from %2$s where time>=%3$d and time<%4$d";

  private static final String MINMAX_UDF = "select MinMax(%1$s,'tqs'='%3$d','tqe'='%4$d','w'='%5$d') from %2$s where time>=%3$d and time<%4$d";

  private static final String LTTB_UDF = "select Sample(%1$s,'method'='triangle','k'='%5$d') from %2$s where time>=%3$d and time<%4$d";

  public static Session session;

  // Usage: java -jar QueryData-0.12.4.jar device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  public static void main(String[] args)
      throws IoTDBConnectionException, StatementExecutionException, TException, IOException {
    String device = args[0];
    System.out.println("[QueryData] device=" + device);
    String measurement = args[1];
    System.out.println("[QueryData] measurement=" + measurement);

    String timestamp_precision = args[2]; // ns, us, ms
    timestamp_precision = timestamp_precision.toLowerCase();
    System.out.println("[QueryData] timestamp_precision=" + timestamp_precision);
    if (!timestamp_precision.toLowerCase().equals("ns") && !timestamp_precision.toLowerCase()
        .equals("us") && !timestamp_precision.toLowerCase().equals("ms")) {
      throw new IOException("timestamp_precision only accepts ns,us,ms.");
    }

    // used to bound tqs random position
    long dataMinTime = Long.parseLong(args[3]);
    System.out.println("[QueryData] dataMinTime=" + dataMinTime);
    long dataMaxTime = Long.parseLong(args[4]);
    System.out.println("[QueryData] dataMaxTime=" + dataMaxTime);

    // [tqs,tqe) range length, i.e., tqe-tqs
    long range = Long.parseLong(args[5]);
    System.out.println("[QueryData] query range=" + range);
    // w数量
    int w = Integer.parseInt(args[6]);
    System.out.println("[QueryData] w=" + w);

    long minTime;
    long maxTime;
    long interval;
    if (range >= (dataMaxTime - dataMinTime)) {
      minTime = dataMinTime;
      interval = (long) Math.ceil((double) (dataMaxTime - dataMinTime) / (2 * w)) * 2;
      // note multiple integer of 2w because MinMax need interval/2
    } else {
      // randomize between [dataMinTime, dataMaxTime-range]
      minTime = (long) Math.ceil(
          dataMinTime + Math.random() * (dataMaxTime - range - dataMinTime + 1));
      interval = (long) Math.ceil((double) range / (2 * w)) * 2;
      // note multiple integer of 2w because MinMax need interval/2
    }
    maxTime = minTime + interval * w;

    String approach = args[7].toLowerCase();
    String sql;
    switch (approach) {
      case "mac": // M4-UDF
        sql = String.format(M4_UDF, measurement, device, minTime, maxTime, w);
        break;
      case "cpv": // M4-LSM
      case "moc": // group-by
        // MOC and CPV sql use the same sql queryFormat.
        sql = String.format(M4_LSM, measurement, measurement, measurement, measurement, measurement,
            measurement, device, minTime, maxTime, interval,
            timestamp_precision);  // note the time precision unit
        break;
      case "minmax":
        sql = String.format(MINMAX_UDF, measurement, device, minTime, maxTime, 2 * w); // note 2w
        break;
      case "lttb":
        sql = String.format(LTTB_UDF, measurement, device, minTime, maxTime, 4 * w); // note 4w
        break;
      case "minmax_lsm":
        sql = String.format(MINMAX_LSM, measurement, measurement, device, minTime, maxTime,
            interval / 2, timestamp_precision);  // note the time precision unit
        // note the interval/2
        break;
      default:
        throw new IOException("Approach wrong. Only accepts mac/moc/cpv/minmax/lttb/minmax_lsm");
    }

    System.out.println("[QueryData] approach=" + approach);
    System.out.println("[QueryData] sql=" + sql);
    if (approach.equals("moc")) {
      System.out.println(
          "MAKE SURE you have set the enable_CPV as false in `iotdb-engine.properties` for MOC!");
    } else if (approach.equals("cpv")) {
      System.out.println(
          "MAKE SURE you have set the enable_CPV as true and enableMinMaxLSM as false in `iotdb-engine.properties` for CPV!");
    } else if (approach.equals("minmax_lsm")) {
      System.out.println(
          "MAKE SURE you have set the enable_CPV and enableMinMaxLSM as true in `iotdb-engine.properties` for CPV!");
    }

    boolean save_query_result = Boolean.parseBoolean(args[8]);
    System.out.println("[QueryData] save_query_result=" + save_query_result);

    String save_query_path = args[9];
    System.out.println("[QueryData] save_query_path=" + save_query_path);

    session = new Session("127.0.0.1", 6667, "root", "root");
    session.open(false);

    // Set it big to avoid multiple fetch, which is very important.
    // Because the IOMonitor implemented in IoTDB does not cover the fetchResults operator yet.
    // As M4 already does data reduction, so even the w is very big such as 8000, the returned
    // query result size is no more than 8000*4=32000.
    session.setFetchSize(1000000);

    if (!save_query_result) {
      long c = 0;
//      long startTime = System.nanoTime();
      SessionDataSet dataSet = session.executeQueryStatement(sql);
      DataIterator ite = dataSet.iterator();
      while (ite.next()) { // this way avoid constructing rowRecord
        c++;
      }
      System.out.println(c);
//      long elapsedTimeNanoSec = System.nanoTime() - startTime;
//      System.out.println("[1-ns]ClientElapsedTime," + elapsedTimeNanoSec);

//      dataSet = session.executeFinish();
//      String info = dataSet.getFinishResult();
//      // don't add more string to this output, as ProcessResult code depends on this.
//      System.out.println(info);
//      System.out.println("[QueryData] query result line number=" + c);

      dataSet.closeOperationHandle();
      session.close();
    } else {
      PrintWriter printWriter = new PrintWriter(save_query_path);
      long c = 0;
//      long startTime = System.nanoTime();
      SessionDataSet dataSet = session.executeQueryStatement(sql);
      while (dataSet.hasNext()) { // this way avoid constructing rowRecord
        RowRecord rowRecord = dataSet.next();
        printWriter.println(rowRecord); // \t separator
        c++;
      }
      System.out.println(c);
//      long elapsedTimeNanoSec = System.nanoTime() - startTime;
//      System.out.println("[1-ns]ClientElapsedTime," + elapsedTimeNanoSec);

//      dataSet = session.executeFinish();
//      String info = dataSet.getFinishResult();
//      // don't add more string to this output, as ProcessResult code depends on this.
//      System.out.println(info);
//      System.out.println("[QueryData] query result line number=" + c);

      dataSet.closeOperationHandle();
      session.close();
      printWriter.close();
    }
  }
}
