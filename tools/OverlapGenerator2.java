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

public class OverlapGenerator2 {

  public static void main(String[] args) throws IOException {
    String dataType = args[0]; // long or double
    if (!dataType.equalsIgnoreCase("long") && !dataType.equalsIgnoreCase("double")) {
      throw new IOException("Data type only accepts long or double.");
    }
    dataType = dataType.toLowerCase();

    String inPath = args[1];
    String outPath = args[2];
    int timeIdx = Integer.parseInt(args[3]);
    int valueIdx = Integer.parseInt(args[4]);
    int pointNum = Integer.parseInt(args[5]);
    int min_IOTDB_CHUNK_POINT_SIZE = Integer.parseInt(args[6]);
    int select = min_IOTDB_CHUNK_POINT_SIZE / 2;

    File f = new File(inPath);
    FileWriter fileWriter = new FileWriter(outPath);
    String line;
    BufferedReader reader = new BufferedReader(new FileReader(f));
    PrintWriter printWriter = new PrintWriter(fileWriter);
    List<Integer> idx = new ArrayList<>();
    for (int i = 0; i < pointNum; i++) {
      idx.add(i);
    }
    Collections.shuffle(idx);
    long[] timestampArray = new long[pointNum];
    Object[] valueArray = new Object[pointNum];
    int cnt = 0;
    while ((line = reader.readLine()) != null && cnt < pointNum) { // no header
      String[] split = line.split(",");
      timestampArray[cnt] = Long.parseLong(split[timeIdx]);
      valueArray[cnt] = parseValue(split[valueIdx], dataType);
      cnt++;
    }

    cnt = 0;
    long select_t = -1;
    Object select_v = null;
    for (int k : idx) {
      cnt++;
      if (cnt == select) {
        select_t = timestampArray[k];
        select_v = valueArray[k];
        printWriter.print(timestampArray[k]);
        printWriter.print(",");
        printWriter.print("11583"); // for MF03
        printWriter.println();
      } else if (cnt < pointNum) {
        printWriter.print(timestampArray[k]);
        printWriter.print(",");
        printWriter.print(valueArray[k]);
        printWriter.println();
      } else { // last overwrite
        printWriter.print(select_t);
        printWriter.print(",");
        printWriter.print(select_v);
        printWriter.println();
      }
    }

    System.out.println(cnt);
    reader.close();
    printWriter.close();
  }

  public static Object parseValue(String value, String dataType) throws IOException {
    if (dataType.equalsIgnoreCase("long")) {
      return Long.parseLong(value);
    } else if (dataType.equalsIgnoreCase("double")) {
      return Double.parseDouble(value);
    } else {
      throw new IOException("Data type only accepts long or double.");
    }
  }

//  public static Object peak(String dataType) throws IOException {
//    if (dataType.equalsIgnoreCase("long")) {
//      return Long.MAX_VALUE; // not Long.MAX_VALUE as that will pollute sdt
//    } else if (dataType.equalsIgnoreCase("double")) {
//      return Double.MAX_VALUE; // not Double.MAX_VALUE as that will pollute sdt
//    } else {
//      throw new IOException("Data type only accepts long or double.");
//    }
//  }
}
