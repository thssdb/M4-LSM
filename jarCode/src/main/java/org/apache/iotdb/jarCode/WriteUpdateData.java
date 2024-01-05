package org.apache.iotdb.jarCode;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import org.apache.iotdb.rpc.IoTDBConnectionException;
import org.apache.iotdb.rpc.StatementExecutionException;
import org.apache.iotdb.session.Session;
import org.apache.iotdb.tsfile.file.metadata.enums.TSDataType;
import org.apache.iotdb.tsfile.file.metadata.enums.TSEncoding;
import org.apache.iotdb.tsfile.write.record.Tablet;
import org.apache.iotdb.tsfile.write.schema.MeasurementSchema;


public class WriteUpdateData {

  /**
   * Before writing data, make sure check the server parameter configurations.
   */
  // Usage: java -jar WriteData-0.12.4.jar
  // device 0
  // measurement 1
  // dataType 2
  // timestamp_precision 3
  // iotdb_chunk_point_size 4
  // filePath 5
  // updatePercentage 6
  // timeIdx 7
  // valueIdx 8
  // valueEncoding 9
  // hasHeader 10
  // java -jar WriteUpdateData-jar-with-dependencies.jar "root.game" "s6" long ns 100 "D:\full-game\tmp.csv" 50 0 1 PLAIN true
  public static void main(String[] args)
      throws IoTDBConnectionException, StatementExecutionException, IOException {
//    Random random = new Random();
//    System.out.println((long) (new Random().nextGaussian() * 10));

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

    int iotdb_chunk_point_size = Integer.parseInt(args[4]);
    System.out.println("[WriteData] iotdb_chunk_point_size=" + iotdb_chunk_point_size);

    // data source
    String filePath = args[5];
    System.out.println("[WriteData] filePath=" + filePath);

    // update percentage
    int updatePercentage = Integer.parseInt(args[6]); // 0 means no updates. 0-100
    if (updatePercentage < 0 || updatePercentage > 100) {
      throw new IOException("WRONG updatePercentage! updatePercentage should be within [0,100]");
    }
    System.out.println("[WriteData] updatePercentage=" + updatePercentage);

    // 时间戳idx，从0开始
    int timeIdx = Integer.parseInt(args[7]);
    System.out.println("[WriteData] timeIdx=" + timeIdx);

    // 值idx，从0开始
    int valueIdx = Integer.parseInt(args[8]);
    System.out.println("[WriteData] valueIdx=" + valueIdx);

    // value encoder
    String valueEncoding = args[9]; // RLE, GORILLA, PLAIN
    System.out.println("[WriteData] valueEncoding=" + valueEncoding);

    boolean hasHeader;
    if (args.length < 11) {
      hasHeader = false; // default
    } else {
      hasHeader = Boolean.parseBoolean(args[10]);
    }

    //"CREATE TIMESERIES root.vehicle.d0.s0 WITH DATATYPE=INT32, ENCODING=RLE"
    String createSql = String.format("CREATE TIMESERIES %s.%s WITH DATATYPE=%s, ENCODING=%s",
        device,
        measurement,
        tsDataType,
        valueEncoding
    );

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

    File f = new File(filePath);
    String line = null;
    BufferedReader reader = new BufferedReader(new FileReader(f));
    if (hasHeader) {
      reader.readLine(); // read header
    }

    List<MeasurementSchema> schemaList = new ArrayList<>();
    schemaList.add(
        new MeasurementSchema(measurement, tsDataType, TSEncoding.valueOf(valueEncoding)));
    Tablet tablet = new Tablet(device, schemaList, iotdb_chunk_point_size);
    long[] timestamps = tablet.timestamps;
    Object[] values = tablet.values;
    long longTopV = Long.MIN_VALUE;
    long longSecTopV = Long.MIN_VALUE;
    double doubleTopV = Double.MIN_VALUE;
    double doubleSecTopV = Double.MIN_VALUE;
    while ((line = reader.readLine()) != null) {
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
          // assume more than one point in tablet
          if (long_value > longTopV) {
            longSecTopV = longTopV;  // note this
            longTopV = long_value; // update top v
          } else if (long_value > longSecTopV) {
            longSecTopV = long_value; // update second top v
          }
          break;
        case DOUBLE:
          double double_value = Double.parseDouble(split[valueIdx]); // get value from real data
          double[] double_sensor = (double[]) values[0];
          double_sensor[row] = double_value;
          // assume more than one point in tablet
          if (double_value > doubleTopV) {
            doubleSecTopV = doubleTopV; // note this
            doubleTopV = double_value; // update top v
          } else if (double_value > doubleSecTopV) {
            doubleSecTopV = double_value; // update second top v
          }
          break;
        default:
          throw new IOException("not supported data type!");
      }
      if (tablet.rowSize == tablet.getMaxRowNumber()) { // chunk point size

        session.insertTablet(tablet, false);

        // update tablet
        if (new Random().nextDouble() < updatePercentage / 100.0) {
          // not <=, as updatePercentage=0 means no update
          // do not reset tablet here
          switch (tsDataType) {
            case INT64:
              if (longTopV == longSecTopV) {
                longSecTopV = longTopV - 1;
              }

              long[] long_sensor = (long[]) values[0];
              for (int i = 0; i < long_sensor.length; i++) {
                long_sensor[i] = long_sensor[i] - (long) (new Random().nextGaussian() * (longTopV
                    - longSecTopV));
              }
              break;
            case DOUBLE:
              if (doubleTopV == doubleSecTopV) {
                doubleSecTopV = doubleTopV - 0.01;
              }

              double[] double_sensor = (double[]) values[0];
              for (int i = 0; i < double_sensor.length; i++) {
                double_sensor[i] = double_sensor[i] - (new Random().nextGaussian() * (doubleTopV
                    - doubleSecTopV));
              }
              break;
            default:
              throw new IOException("not supported data type!");
          }
          session.insertTablet(tablet, false);
        }

        tablet.reset(); // only reset here
        longTopV = Long.MIN_VALUE;
        longSecTopV = Long.MIN_VALUE;
        doubleTopV = Double.MIN_VALUE;
        doubleSecTopV = Double.MIN_VALUE;
      }
    }
    // flush the last Tablet
    if (tablet.rowSize != 0) {
      session.insertTablet(tablet, false);
      tablet.reset();
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
