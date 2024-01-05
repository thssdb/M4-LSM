package org.apache.iotdb.tools;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class ProcessQueryPlotResult {

  public static String[] QueryPlotPrint = new String[]{
      "[1-ns]transfer_data",
      "[1-ns]parse_data",
      "[1-ns]plot_data",
      "[2-ns]Server_Query_Execute", "[2-ns]Server_Query_Fetch", "[3]dataSetType",
      "[3-ns]M4_LSM_init_loadAllChunkMetadatas", "[3-ns]M4_LSM_merge_M4_time_span",
      "[3-ns]M4_LSM_FP", "[3-ns]M4_LSM_LP", "[3-ns]M4_LSM_BP", "[3-ns]M4_LSM_TP",
      "[4-ns]DCP_A_GET_CHUNK_METADATAS", "[4-ns]DCP_B_READ_MEM_CHUNK",
      "[4-ns]DCP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA",
      "[4-ns]DCP_D_DECODE_PAGEDATA_TRAVERSE_POINTS", "[4-ns]SEARCH_ARRAY_a_verifBPTP",
      "[4-ns]SEARCH_ARRAY_b_genFP", "[4-ns]SEARCH_ARRAY_b_genLP", "[4-ns]SEARCH_ARRAY_c_genBPTP",
      "[2-cnt]Server_Query_Execute", "[2-cnt]Server_Query_Fetch",
      "[3-cnt]M4_LSM_init_loadAllChunkMetadatas", "[3-cnt]M4_LSM_merge_M4_time_span",
      "[3-cnt]M4_LSM_FP", "[3-cnt]M4_LSM_LP", "[3-cnt]M4_LSM_BP", "[3-cnt]M4_LSM_TP",
      "[4-cnt]DCP_A_GET_CHUNK_METADATAS", "[4-cnt]DCP_B_READ_MEM_CHUNK",
      "[4-cnt]DCP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA",
      "[4-cnt]DCP_D_DECODE_PAGEDATA_TRAVERSE_POINTS", "[4-cnt]SEARCH_ARRAY_a_verifBPTP",
      "[4-cnt]SEARCH_ARRAY_b_genFP", "[4-cnt]SEARCH_ARRAY_b_genLP", "[4-cnt]SEARCH_ARRAY_c_genBPTP",
      "[4-cnt]DCP_D_traversedPointNum", "[3-4]M4_LSM_merge_M4_time_span_B_READ_MEM_CHUNK_cnt",
      "[3-4]M4_LSM_merge_M4_time_span_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA_cnt",
      "[3-4]M4_LSM_merge_M4_time_span_SEARCH_ARRAY_a_verifBPTP_cnt",
      "[3-4]M4_LSM_merge_M4_time_span_SEARCH_ARRAY_b_genFP_cnt",
      "[3-4]M4_LSM_merge_M4_time_span_SEARCH_ARRAY_b_genLP_cnt",
      "[3-4]M4_LSM_merge_M4_time_span_SEARCH_ARRAY_c_genBPTP_cnt",
      "[3-4]M4_LSM_FP_B_READ_MEM_CHUNK_cnt",
      "[3-4]M4_LSM_FP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA_cnt",
      "[3-4]M4_LSM_FP_SEARCH_ARRAY_a_verifBPTP_cnt", "[3-4]M4_LSM_FP_SEARCH_ARRAY_b_genFP_cnt",
      "[3-4]M4_LSM_FP_SEARCH_ARRAY_b_genLP_cnt", "[3-4]M4_LSM_FP_SEARCH_ARRAY_c_genBPTP_cnt",
      "[3-4]M4_LSM_LP_B_READ_MEM_CHUNK_cnt",
      "[3-4]M4_LSM_LP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA_cnt",
      "[3-4]M4_LSM_LP_SEARCH_ARRAY_a_verifBPTP_cnt", "[3-4]M4_LSM_LP_SEARCH_ARRAY_b_genFP_cnt",
      "[3-4]M4_LSM_LP_SEARCH_ARRAY_b_genLP_cnt", "[3-4]M4_LSM_LP_SEARCH_ARRAY_c_genBPTP_cnt",
      "[3-4]M4_LSM_BP_B_READ_MEM_CHUNK_cnt",
      "[3-4]M4_LSM_BP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA_cnt",
      "[3-4]M4_LSM_BP_SEARCH_ARRAY_a_verifBPTP_cnt", "[3-4]M4_LSM_BP_SEARCH_ARRAY_b_genFP_cnt",
      "[3-4]M4_LSM_BP_SEARCH_ARRAY_b_genLP_cnt", "[3-4]M4_LSM_BP_SEARCH_ARRAY_c_genBPTP_cnt",
      "[3-4]M4_LSM_TP_B_READ_MEM_CHUNK_cnt",
      "[3-4]M4_LSM_TP_C_DESERIALIZE_PAGEHEADER_DECOMPRESS_PAGEDATA_cnt",
      "[3-4]M4_LSM_TP_SEARCH_ARRAY_a_verifBPTP_cnt", "[3-4]M4_LSM_TP_SEARCH_ARRAY_b_genFP_cnt",
      "[3-4]M4_LSM_TP_SEARCH_ARRAY_b_genLP_cnt", "[3-4]M4_LSM_TP_SEARCH_ARRAY_c_genBPTP_cnt",};

  public static void main(String[] args) throws IOException {

    String inFilePath = args[0]; // complete running repetition test log
    String outFilePath = args[1]; // extracted metrics log
    String sumOutFilePath = args[2]; // average metrics appending file
    int numberOfRawDataPoints = Integer.parseInt(args[3]);

    BufferedReader reader = new BufferedReader(new FileReader(inFilePath));
    FileWriter writer = new FileWriter(outFilePath);

    FileWriter sumWriter = new FileWriter(sumOutFilePath, true); // append
    File file = new File(sumOutFilePath);
    if (!file.exists() || file.length() == 0) { // write header for sumOutFilePath
      sumWriter.write(String.join(",", QueryPlotPrint)
          + ",numberOfRawDataPoints,"
          + "server_processing_time_ns,"
          + "communication_time_ns,"
          + "client_processing_time_ns,"
          + "total_response_time_ns"
          + "\n");
    }

    Map<String, Long> metrics_ns = new HashMap<>();
    Map<String, Integer> metrics_cnt = new HashMap<>();
    String dataSetType = "NONE";
    String readLine;
    int repetition = 0;
    while ((readLine = reader.readLine()) != null) {
      String metric = whichMetric(readLine);
      if (metric != null) {
        if (metric.equals("[1-ns]transfer_data")) {
          // NOTE this is important, ensure this metric appears once and only once in each repetition test
          repetition++;
        }
        String[] values = readLine.split(",");
        if (metric.contains("-ns") || metric.contains("_ns")) {
          long time_ns = Long.parseLong(values[1]);
          sumMetric(metric, time_ns, metrics_ns);
        } else if (metric.contains("-cnt") || metric.contains("-count") || metric.contains("_cnt")
            || metric.contains("_count")) {
          int op_cnt = Integer.parseInt(values[1]);
          sumMetric(metric, op_cnt, metrics_cnt);
        } else {
          dataSetType = values[1];
        }
        writer.write(readLine + "\n");
      }
    }

    for (int i = 0; i < QueryPlotPrint.length; i++) {
      String metric = QueryPlotPrint[i];
      if (metric.contains("-ns") || metric.contains("_ns")) {
        if (metrics_ns.containsKey(metric)) {
          sumWriter.write((double) metrics_ns.get(metric) / repetition + "");
        } else { // "diskFile" read method does not print iotdb server metrics
          sumWriter.write("0");
        }
      } else if (metric.contains("-cnt") || metric.contains("-count") || metric.contains("_cnt")
          || metric.contains("_count")) {
        if (metrics_cnt.containsKey(metric)) {
          sumWriter.write((double) metrics_cnt.get(metric) / repetition + "");
        } else { // "diskFile" read method does not print iotdb server metrics
          sumWriter.write("0");
        }
      } else {
        sumWriter.write(dataSetType);
      }
      sumWriter.write(",");
    }

    sumWriter.write(numberOfRawDataPoints + ",");
    double server_processing_time_ns = 0;
    double communication_time_ns = 0;
    double client_processing_time_ns = 0;
    double total_response_time_ns = 0;
    if (metrics_ns.containsKey("[2-ns]Server_Query_Execute")) {
      server_processing_time_ns =
          (double) metrics_ns.get("[2-ns]Server_Query_Execute") / repetition;
    }
    sumWriter.write(server_processing_time_ns + ",");
    if (metrics_ns.containsKey("[1-ns]transfer_data")) {
      communication_time_ns = (double) metrics_ns.get("[1-ns]transfer_data") / repetition;
    }
    sumWriter.write(communication_time_ns + ",");
    if (metrics_ns.containsKey("[1-ns]parse_data")) {
      client_processing_time_ns += (double) metrics_ns.get("[1-ns]parse_data") / repetition;
    }
    if (metrics_ns.containsKey("[1-ns]plot_data")) {
      client_processing_time_ns += (double) metrics_ns.get("[1-ns]plot_data") / repetition;
    }
    sumWriter.write(client_processing_time_ns + ",");
    total_response_time_ns =
        server_processing_time_ns + communication_time_ns + client_processing_time_ns;
    sumWriter.write(total_response_time_ns + "\n");
    reader.close();
    writer.close();
    sumWriter.close();
  }

  public static String whichMetric(String line) {
    for (String metricName : QueryPlotPrint) {
      if (line.contains(metricName)) {
        return metricName;
      }
    }
    return null;
  }

  public static void sumMetric(String metric, long time_ns, Map<String, Long> metrics_ns) {
    if (metrics_ns.containsKey(metric)) {
      metrics_ns.put(metric, time_ns + metrics_ns.get(metric));
    } else {
      metrics_ns.put(metric, time_ns);
    }
  }

  public static void sumMetric(String metric, int op_cnt, Map<String, Integer> metrics_cnt) {
    if (metrics_cnt.containsKey(metric)) {
      metrics_cnt.put(metric, op_cnt + metrics_cnt.get(metric));
    } else {
      metrics_cnt.put(metric, op_cnt);
    }
  }
}
