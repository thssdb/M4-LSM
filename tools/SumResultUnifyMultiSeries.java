package org.apache.iotdb.tools;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;

public class SumResultUnifyMultiSeries {

  public static void main(String[] args) throws IOException {
    String raw = args[0]; // sumResultRAW.csv
    String mac = args[1]; // sumResultMAC.csv
    String cpv = args[2]; // sumResultCPV.csv

    String out = args[3];

    BufferedReader macReader = new BufferedReader(new FileReader(mac));
    BufferedReader cpvReader = new BufferedReader(new FileReader(cpv));
    BufferedReader rawReader = new BufferedReader(new FileReader(raw));
    PrintWriter printWriter = new PrintWriter(new FileWriter(out));
    String macLine;
    String cpvLine;
    String rawLine;
    String appendLine;
    boolean isHeader = true;
    while ((macLine = macReader.readLine()) != null) {
      cpvLine = cpvReader.readLine();
      rawLine = rawReader.readLine();

      if (isHeader) {
        macLine = "MAC_" + macLine;
        cpvLine = "CPV_" + cpvLine;
        rawLine = "RAW_" + rawLine;
        isHeader = false;
      }

      appendLine = rawLine + "," + macLine + "," + cpvLine;
      printWriter.println(appendLine);
    }
    printWriter.close();
    macReader.close();
    cpvReader.close();
    rawReader.close();
  }
}
