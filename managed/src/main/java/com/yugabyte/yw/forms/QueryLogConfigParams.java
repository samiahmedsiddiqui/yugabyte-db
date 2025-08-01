package com.yugabyte.yw.forms;

import static play.mvc.Http.Status.BAD_REQUEST;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.yugabyte.yw.common.PlatformServiceException;
import com.yugabyte.yw.models.Universe;
import com.yugabyte.yw.models.helpers.exporters.query.QueryLogConfig;
import org.apache.commons.collections4.CollectionUtils;

@JsonIgnoreProperties(ignoreUnknown = true)
@JsonDeserialize(converter = QueryLogConfigParams.Converter.class)
public class QueryLogConfigParams extends UpgradeTaskParams {

  public boolean installOtelCollector;
  public QueryLogConfig queryLogConfig;

  @Override
  public boolean isKubernetesUpgradeSupported() {
    return true;
  }

  @Override
  public void verifyParams(Universe universe, boolean isFirstTry) {
    super.verifyParams(universe, isFirstTry);
    boolean exportEnabled =
        queryLogConfig.isExportActive()
            && CollectionUtils.isNotEmpty(queryLogConfig.getUniverseLogsExporterConfig());
    if (exportEnabled
        && !universe.getUniverseDetails().otelCollectorEnabled
        && !installOtelCollector) {
      throw new PlatformServiceException(
          BAD_REQUEST,
          "Universe "
              + universe.getUniverseUUID()
              + " does not have OpenTelemetry Collector "
              + "installed and task params has installOtelCollector=false - can't configure query "
              + "logs export for the universe");
    }
  }

  public static class Converter extends BaseConverter<QueryLogConfigParams> {}
}
