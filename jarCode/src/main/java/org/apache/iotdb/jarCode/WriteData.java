package org.apache.iotdb.jarCode;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.apache.iotdb.rpc.IoTDBConnectionException;
import org.apache.iotdb.rpc.StatementExecutionException;
import org.apache.iotdb.session.Session;
import org.apache.iotdb.tsfile.file.metadata.enums.TSDataType;
import org.apache.iotdb.tsfile.file.metadata.enums.TSEncoding;
import org.apache.iotdb.tsfile.write.record.Tablet;
import org.apache.iotdb.tsfile.write.schema.MeasurementSchema;

// write in batch mode,
// and separate insert and delete to avoid 1) delete points in memory 2) trigger repeated deletes
public class WriteData {

  /**
   * Before writing data, make sure check the server parameter configurations.
   */
  // Usage: java -jar WriteData-0.12.4.jar device measurement dataType timestamp_precision total_time_length total_point_number iotdb_chunk_point_size filePath deleteFreq deleteLen timeIdx valueIdx valueEncoding
  public static void main(String[] args)
      throws IoTDBConnectionException, StatementExecutionException, IOException {
    String device = args[0];
    System.out.println("[WriteData] device=" + device);
    String measurement = args[1];
    System.out.println("[WriteData] measurement=" + measurement);
    String dataType = args[2]; // long or double
    System.out.println("[WriteData] dataType=" + dataType);
    TSDataType tsDataType;
    if (dataType.toLowerCase().equals("long")) {
      tsDataType = TSDataType.INT64;
    } else if (dataType.toLowerCase().equals("double")) {
      tsDataType = TSDataType.DOUBLE;
    } else {
      throw new IOException("Data type only accepts long or double.");
    }

    String timestamp_precision = args[3]; // ns, us, ms
    System.out.println("[WriteData] timestamp_precision=" + timestamp_precision);
    if (!timestamp_precision.toLowerCase().equals("ns") && !timestamp_precision.toLowerCase()
        .equals("us") && !timestamp_precision.toLowerCase().equals("ms")) {
      throw new IOException("timestamp_precision only accepts ns,us,ms.");
    }

    long total_time_length = Long.parseLong(args[4]); // in corresponding timestamp precision
    System.out.println("[WriteData] total_time_length=" + total_time_length);
    int total_point_number = Integer.parseInt(args[5]);
    System.out.println("[WriteData] total_point_number=" + total_point_number);
    int iotdb_chunk_point_size = Integer.parseInt(args[6]);
    System.out.println("[WriteData] iotdb_chunk_point_size=" + iotdb_chunk_point_size);

    long chunkAvgTimeLen =
        (long) Math
            .ceil(total_time_length / Math.ceil(total_point_number * 1.0 / iotdb_chunk_point_size));
    System.out.println("[WriteData] derived estimated chunkAvgTimeLen =" + chunkAvgTimeLen);

    // 乱序数据源
    String filePath = args[7];
    System.out.println("[WriteData] filePath=" + filePath);
    // delete percentage
    int deletePercentage = Integer.parseInt(args[8]); // 0 means no deletes. 0-100
    System.out.println("[WriteData] deletePercentage=" + deletePercentage);
    // 每次删除的时间长度，用chunkAvgTimeLen的百分比表示
    int deleteLenPercentage = Integer.parseInt(args[9]); // 0-100
    System.out.println("[WriteData] deleteLenPercentage=" + deleteLenPercentage);
    // 时间戳idx，从0开始
    int timeIdx = Integer.parseInt(args[10]);
    System.out.println("[WriteData] timeIdx=" + timeIdx);
    // 值idx，从0开始
    int valueIdx = Integer.parseInt(args[11]);
    System.out.println("[WriteData] valueIdx=" + valueIdx);
    // value encoder
    String valueEncoding = args[12]; // RLE, GORILLA, PLAIN
    System.out.println("[WriteData] valueEncoding=" + valueEncoding);

    boolean hasHeader;
    if (args.length < 14) {
      hasHeader = false; // default
    } else {
      hasHeader = Boolean.parseBoolean(args[13]);
    }

    //"CREATE TIMESERIES root.vehicle.d0.s0 WITH DATATYPE=INT32, ENCODING=RLE"
    String createSql = String.format("CREATE TIMESERIES %s.%s WITH DATATYPE=%s, ENCODING=%s",
        device,
        measurement,
        tsDataType,
        valueEncoding
    );

    if (deletePercentage < 0 || deletePercentage > 100) {
      throw new IOException("WRONG deletePercentage! deletePercentage should be within [0,100]");
    }
    if (deleteLenPercentage < 0 || deleteLenPercentage > 100) {
      throw new IOException(
          "WRONG deleteLenPercentage! deleteLenPercentage should be within [0,100]");
    }
    if (deletePercentage > 0 && deleteLenPercentage == 0) {
      throw new IOException(
          "WRONG deleteLenPercentage! when deletePercentage>0, so should deleteLenPercentage");
    }

    int deletePeriod = Integer.MAX_VALUE;
    if (deletePercentage > 0) {
      // insert a delete when every 100/deletePercentage chunks are inserted,
      // thus to meet the deletePercentage target.
      // using the number of chunks inserted as deletePercentage baseline is to
      // avoid the delete operation being handled in memory.
      deletePeriod =
          (int) Math.floor(100 * 1.0 / deletePercentage
              * iotdb_chunk_point_size);
    }

    // the delete time range length is deleteLenPercentage of chunkAvgTimeLen
    long deleteLen = (long) Math.floor(chunkAvgTimeLen * deleteLenPercentage * 1.0 / 100);

    List<String> deletePaths = new ArrayList<>();
    deletePaths.add(device + "." + measurement);

    Session session = new Session("127.0.0.1", 6667, "root", "root");
    session.open(false);
    session.executeNonQueryStatement(createSql);

    // this is to make all following inserts unseq chunks
    if (timestamp_precision.toLowerCase().equals("ns")) {
      session.insertRecord(
          device,
          1683616109697000000L, // ns
          // NOTE UPDATE TIME DATATYPE! [[update]]. DONT USE System.nanoTime()!
          Collections.singletonList(measurement),
          Collections.singletonList(tsDataType), // NOTE UPDATE VALUE DATATYPE!
          parseValue("0", tsDataType)); // NOTE UPDATE VALUE DATATYPE!
    } else if (timestamp_precision.toLowerCase().equals("us")) {
      session.insertRecord(
          device,
          1683616109697000L, // us
          // NOTE UPDATE TIME DATATYPE! [[update]]. DONT USE System.nanoTime()!
          Collections.singletonList(measurement),
          Collections.singletonList(tsDataType), // NOTE UPDATE VALUE DATATYPE!
          parseValue("0", tsDataType)); // NOTE UPDATE VALUE DATATYPE!
    } else { // ms
      session.insertRecord(
          device,
          1683616109697L, // ms
          // NOTE UPDATE TIME DATATYPE! [[update]]. DONT USE System.nanoTime()!
          Collections.singletonList(measurement),
          Collections.singletonList(tsDataType), // NOTE UPDATE VALUE DATATYPE!
          parseValue("0", tsDataType)); // NOTE UPDATE VALUE DATATYPE!
    }
    session.executeNonQueryStatement("flush");

    List<Long> deleteStartTimeList = new ArrayList<>();
    List<Long> deleteEndTimeList = new ArrayList<>();
    File f = new File(filePath);
    String line = null;
    BufferedReader reader = new BufferedReader(new FileReader(f));
    if (hasHeader) {
      reader.readLine(); // read header
    }
    long lastDeleteMinTime = Long.MAX_VALUE;
    long lastDeleteMaxTime = Long.MIN_VALUE;
    int cnt = 0;

    List<MeasurementSchema> schemaList = new ArrayList<>();
    schemaList.add(
        new MeasurementSchema(measurement, tsDataType, TSEncoding.valueOf(valueEncoding)));
    Tablet tablet = new Tablet(device, schemaList, iotdb_chunk_point_size);
    long[] timestamps = tablet.timestamps;
    Object[] values = tablet.values;

    while ((line = reader.readLine()) != null) {
      cnt++;
      String[] split = line.split(",");
      long timestamp = Long.parseLong(split[timeIdx]);

      //  change to batch mode, iotdb_chunk_point_size
      int row = tablet.rowSize++;
      timestamps[row] = timestamp;
      switch (tsDataType) {
        case INT64:
          long long_value = Long.parseLong(split[valueIdx]); // get value from real data
          long[] long_sensor = (long[]) values[0];
          long_sensor[row] = long_value;
          break;
        case DOUBLE:
          double double_value = Double.parseDouble(split[valueIdx]); // get value from real data
          double[] double_sensor = (double[]) values[0];
          double_sensor[row] = double_value;
          break;
        default:
          throw new IOException("not supported data type!");
      }
      if (tablet.rowSize == tablet.getMaxRowNumber()) { // chunk point size
        session.insertTablet(tablet, false);
        tablet.reset();
      }

      // generate delete start and end time
      if (timestamp > lastDeleteMaxTime) {
        lastDeleteMaxTime = timestamp;
      }
      if (timestamp < lastDeleteMinTime) {
        lastDeleteMinTime = timestamp;
      }
      if (deletePercentage > 0) {
        if (cnt >= deletePeriod) {
          cnt = 0;
          // randomize deleteStartTime in [lastMinTime, max(lastMaxTime-deleteLen,lastMinTime+1)]
          long rightBound = Math.max(lastDeleteMaxTime - deleteLen, lastDeleteMinTime + 1);
          long deleteStartTime =
              (long)
                  Math.ceil(
                      lastDeleteMinTime + Math.random() * (rightBound - lastDeleteMinTime + 1));
          long deleteEndTime = deleteStartTime + deleteLen - 1;
          deleteStartTimeList.add(deleteStartTime);
          deleteEndTimeList.add(deleteEndTime);

          lastDeleteMinTime = Long.MAX_VALUE;
          lastDeleteMaxTime = Long.MIN_VALUE;
        }
      }
    }
    // flush the last Tablet
    if (tablet.rowSize != 0) {
      session.insertTablet(tablet, false);
      tablet.reset();
    }
    session.executeNonQueryStatement("flush");

    // separate insert and delete to avoid 1) delete points in memory 2) trigger repeat deletes
    for (int i = 0; i < deleteStartTimeList.size(); i++) {
      session.deleteData(deletePaths, deleteStartTimeList.get(i), deleteEndTimeList.get(i));
      System.out.println(
          "[[[[delete]]]]]" + deleteStartTimeList.get(i) + "," + deleteEndTimeList.get(i));
    }
    session.executeNonQueryStatement("flush");
    session.close();
  }

  public static Object parseValue(String value, TSDataType tsDataType) throws IOException {
    if (tsDataType == TSDataType.INT64) {
      return Long.parseLong(value);
    } else if (tsDataType == TSDataType.DOUBLE) {
      return Double.parseDouble(value);
    } else {
      throw new IOException("data type wrong");
    }
  }
}
