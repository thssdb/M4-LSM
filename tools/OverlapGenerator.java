package org.apache.iotdb.tools;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * 0<=OP<=100 0<=OD<=50. Usage: java OverlapGenerator iotdb_chunk_point_size dataType inPath outPath
 * timeIdx valueIdx overlapPercentage overlapDepth
 */
public class OverlapGenerator {

  public static void main(String[] args) throws IOException {
    int iotdb_chunk_point_size = Integer.parseInt(args[0]);

    String dataType = args[1]; // long or double
    if (!dataType.toLowerCase().equals("long") && !dataType.toLowerCase().equals("double")) {
      throw new IOException("Data type only accepts long or double.");
    }
    dataType = dataType.toLowerCase();

    String inPath = args[2];
    String outPath = args[3];
    int timeIdx = Integer.parseInt(args[4]);
    int valueIdx = Integer.parseInt(args[5]);
    int overlapPercentage = Integer.parseInt(args[6]); // 0-100
    int overlapDepth = Integer.parseInt(args[7]); // 0-50

    boolean hasHeader;
    if (args.length < 9) {
      hasHeader = false; // default
    } else {
      hasHeader = Boolean.parseBoolean(args[8]);
    }

    if (overlapPercentage < 0 || overlapPercentage > 100) {
      throw new IOException("WRONG overlapPercentage");
    }
    if (overlapDepth > 50 || overlapDepth < 0) {
      throw new IOException("WRONG pointNum");
    }
    int pointNum = (int) Math.floor(iotdb_chunk_point_size * (overlapDepth / 100.0));

    File f = new File(inPath);
    FileWriter fileWriter = new FileWriter(outPath);
    String line;
    BufferedReader reader = new BufferedReader(new FileReader(f));
    PrintWriter printWriter = new PrintWriter(fileWriter);
    if (hasHeader) {
      String header = reader.readLine();
      printWriter.println(header);
    }
    int cnt = 0;
    while ((line = reader.readLine()) != null) {
      String[] split = line.split(",");
      long timestamp = Long.parseLong(split[timeIdx]); // time
//      long value = Long.parseLong(split[valueIdx]); // value
      Object value = parseValue(split[valueIdx], dataType);

      // note the first timestamp is never disordered. is global minimal.
      printWriter.print(timestamp);
      printWriter.print(",");
      printWriter.print(value);
      printWriter.println();
      cnt++;

      if (overlapPercentage != 0) {
        while (cnt % iotdb_chunk_point_size == iotdb_chunk_point_size - pointNum) {
          if (new Random().nextDouble() <= overlapPercentage / 100.0) {
            // disturb the next 2*pointNum points
            long[] timestampArray = new long[2 * pointNum];
//            long[] valueArray = new long[2 * pointNum];
            Object[] valueArray = new Object[2 * pointNum];
            List<Integer> idx = new ArrayList<>();
            int n = 0;
            while (n < 2 * pointNum && (line = reader.readLine()) != null) {
              // don't change the sequence of the above two conditions
              split = line.split(",");
              timestampArray[n] = Long.parseLong(split[timeIdx]);
//              valueArray[n] = Long.parseLong(split[valueIdx]);
              valueArray[n] = parseValue(split[valueIdx], dataType);
              idx.add(n);
              n++;
            }
            Collections.shuffle(idx);
            for (Integer integer : idx) {
              int k = integer;
              printWriter.print(timestampArray[k]);
              printWriter.print(",");
              printWriter.print(valueArray[k]);
              printWriter.println();
              cnt++;
            }
          } else {
            int n = 0;
            while (n < 2 * pointNum && (line = reader.readLine()) != null) {
              // don't change the sequence of the above two conditions
              split = line.split(",");
              timestamp = Long.parseLong(split[timeIdx]); // time
//              value = Long.parseLong(split[valueIdx]); // value
              value = parseValue(split[valueIdx], dataType);
              printWriter.print(timestamp);
              printWriter.print(",");
              printWriter.print(value);
              printWriter.println();
              cnt++;
              n++;
            }
          }
        }
      }
    }
    System.out.println(cnt);
    reader.close();
    printWriter.close();
  }

  public static Object parseValue(String value, String dataType) throws IOException {
    if (dataType.toLowerCase().equals("long")) {
      return Long.parseLong(value);
    } else if (dataType.toLowerCase().equals("double")) {
      return Double.parseDouble(value);
    } else {
      throw new IOException("Data type only accepts long or double.");
    }
  }
}
