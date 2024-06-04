import { useEffect, useState, ChangeEvent } from 'react';
import { usePrevious } from 'react-use';
import { useMutation } from 'react-query';
import { useUpdateEffect } from 'react-use';
import { Box, Typography } from '@material-ui/core';
import _, { groupBy } from 'lodash';
import clsx from 'clsx';
import { SecondaryDashboardHeader } from './SecondaryDashboardHeader';
import { ASH_GROUPBY_VALUES, SecondaryDashboard } from './SecondaryDashboard';
import { TroubleshootAPI } from '../api';
import {
  Anomaly,
  AppName,
  GraphLabel,
  GraphQuery,
  GraphResponse,
  GraphType,
  MetricMeasure,
  SplitMode,
  SplitType,
  Universe
} from '../helpers/dtos';
import {
  YBPanelItem,
  isEmptyArray,
  isNonEmptyArray,
  isNonEmptyObject,
  isNonEmptyString
} from '@yugabytedb/ui-components';
import {
  getAnomalyMetricMeasure,
  getAnomalyOutlierType,
  getAnomalyNumNodes,
  getAnomalyStartDate,
  getAnomalyEndTime
} from '../helpers/utils';
import {
  ALL,
  filterDurations,
  MAX_OUTLIER_NUM_NODES,
  ALL_REGIONS,
  ALL_ZONES,
  ASH
} from '../helpers/constants';
import { useHelperStyles } from './styles';

import TraingleDownIcon from '../assets/traingle-down.svg';
import TraingleUpIcon from '../assets/traingle-up.svg';

export interface SecondaryDashboardDataProps {
  anomalyData: Anomaly | null;
  universeUuid: string;
  universeData: Universe | any;
  appName: AppName;
  graphParams: GraphQuery[] | null;
  timezone?: string;
  recommendationMetrics: any;
  hostUrl?: string;
  universeQueryData: any;
}

export const SecondaryDashboardData = ({
  universeUuid,
  universeData,
  anomalyData,
  graphParams,
  appName,
  timezone,
  recommendationMetrics,
  hostUrl,
  universeQueryData
}: SecondaryDashboardDataProps) => {
  // const classes = useStyles();
  const classes = useHelperStyles();
  // Get default values to be populated on page
  const anomalyMetricMeasure = getAnomalyMetricMeasure(anomalyData!);
  const anomalyOutlierType = getAnomalyOutlierType(anomalyData!);
  const anomalyOutlierNumNodes = getAnomalyNumNodes(anomalyData!);
  const anomalyStartDate = getAnomalyStartDate(anomalyData!);
  const anomalyEndDate = getAnomalyEndTime(anomalyData!);
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  // State variables
  const [graphQueryParams, setGraphQueryParams] = useState<any>(graphParams);
  const [openTiles, setOpenTiles] = useState<string[]>([]);
  const [clusterRegionItem, setClusterRegionItem] = useState<string>(ALL_REGIONS);
  const [zoneNodeItem, setZoneNodeItem] = useState<string>(ALL_ZONES);
  const [isPrimaryCluster, setIsPrimaryCluster] = useState<boolean>(true);
  const [cluster, setCluster] = useState<string>(ALL);
  const [region, setRegion] = useState<string>(ALL);
  const [zone, setZone] = useState<string>(ALL);
  const [node, setNode] = useState<string>(ALL);
  const [metricMeasure, setMetricMeasure] = useState<string>(anomalyMetricMeasure);
  const [outlierType, setOutlierType] = useState<SplitMode>(anomalyOutlierType);
  const [filterDuration, setFilterDuration] = useState<string>(
    anomalyStartDate ? filterDurations[filterDurations.length - 1].label : filterDurations[0].label
  );
  const [numNodes, setNumNodes] = useState<number>(anomalyOutlierNumNodes);
  const [startDateTime, setStartDateTime] = useState<Date>(anomalyStartDate ?? yesterday);
  const [endDateTime, setEndDateTime] = useState<Date>(anomalyEndDate ?? today);
  const [graphData, setGraphData] = useState<any>(null);

  // Check previous props
  const previousMetricMeasure = usePrevious(metricMeasure);

  // Make use of useMutation to call fetchGraphs and onSuccess of it, ensure to set setChartData
  useUpdateEffect(() => {
    if (previousMetricMeasure && previousMetricMeasure !== metricMeasure) {
      setGraphData(null);
    }

    const graphParamsCopy = JSON.parse(JSON.stringify(graphQueryParams));

    const formattedStartDate = startDateTime?.toISOString();
    const formattedEndDate = endDateTime?.toISOString();

    graphParamsCopy?.map((params: GraphQuery, paramsIdx: number) => {
      const settings = params.settings;
      const filters = params.filters;
      let start = params.start;
      let end = params.end;

      if (start !== formattedStartDate) {
        params.start = formattedStartDate;
      }

      if (end !== formattedEndDate) {
        params.end = formattedEndDate;
      }
      if (isNonEmptyString(cluster) && cluster !== ALL) {
        filters.clusterUuid = [cluster];
      }
      if (isNonEmptyString(region) && region !== ALL) {
        filters.regionCode = [region];
      }
      if (isNonEmptyString(zone) && zone !== ALL) {
        filters.azCode = [zone];
      }
      if (isNonEmptyString(node) && node !== ALL) {
        filters.instanceName = [node];
      }
      if (params.name.startsWith('active_session_history')) {
        params.groupBy = [];
      }
      settings.returnAggregatedValue = metricMeasure !== MetricMeasure.OVERALL;
      settings.splitType =
        metricMeasure === MetricMeasure.OVERALL
          ? SplitType.NONE
          : metricMeasure === MetricMeasure.OUTLIER
          ? SplitType.NODE
          : SplitType.TABLE;
      settings.splitMode = metricMeasure === MetricMeasure.OVERALL ? SplitMode.NONE : outlierType;
      settings.splitCount = numNodes;
      return settings;
    });

    const actualQueryParams = graphParamsCopy ?? graphQueryParams;
    setGraphQueryParams(actualQueryParams);
    fetchAnomalyGraphs.mutate(actualQueryParams);
  }, [
    numNodes,
    metricMeasure,
    filterDuration,
    outlierType,
    node,
    zone,
    region,
    cluster,
    endDateTime,
    startDateTime,
    anomalyData?.graphStartTime,
    anomalyData?.graphEndTime
  ]);

  const fetchAnomalyGraphs = useMutation(
    (params: any) => TroubleshootAPI.fetchGraphs(universeUuid, params, hostUrl),
    {
      onSuccess: (graphData: GraphResponse[]) => {
        setGraphData(graphData);
      },
      onError: (error: any) => {
        console.error('Failed to fetch graphs', error);
      }
    }
  );

  const onSelectAshLabel = (groupByLabel: string, metricData: any) => {
    let groupBy = ASH_GROUPBY_VALUES.WAIT_EVENT_COMPONENT;
    if (groupByLabel === 'Class') {
      groupBy = ASH_GROUPBY_VALUES.WAIT_EVENT_CLASS;
    } else if (groupByLabel === 'Type') {
      groupBy = ASH_GROUPBY_VALUES.WAIT_EVENT_TYPE;
    } else if (groupByLabel === 'Event') {
      groupBy = ASH_GROUPBY_VALUES.WAIT_EVENT;
    } else if (groupByLabel === 'Query') {
      groupBy = ASH_GROUPBY_VALUES.QUERY;
    } else if (groupByLabel === 'Client IP') {
      groupBy = ASH_GROUPBY_VALUES.CLIENT_NODE_IP;
    }
    const graphParamsCopy = JSON.parse(JSON.stringify(graphQueryParams));
    const ashGraph = graphParamsCopy?.find(
      (queryParams: GraphQuery, idx: number) => idx > 0 && queryParams.name === metricData?.name
    );
    if (ashGraph) {
      ashGraph.groupBy = [groupBy];
    }
    graphParamsCopy.map((obj: any, paramsIdx: number) => {
      if (paramsIdx > 0 && obj.name === metricData?.name) {
        return ashGraph;
      }
      return obj;
    });
    setGraphQueryParams(graphParamsCopy);
    fetchAnomalyGraphs.mutate(graphParamsCopy);
  };

  useEffect(() => {
    fetchAnomalyGraphs.mutate(graphQueryParams);
  }, []);

  const onSplitTypeSelected = (metricMeasure: string) => {
    setMetricMeasure(metricMeasure);
  };

  const onOutlierTypeSelected = (outlierType: SplitMode) => {
    setOutlierType(outlierType);
  };

  const onNumNodesChanged = (numNodes: number) => {
    setNumNodes(numNodes > MAX_OUTLIER_NUM_NODES ? MAX_OUTLIER_NUM_NODES : numNodes);
  };

  const onSelectedFilterDuration = (filterDuration: string) => {
    setFilterDuration(filterDuration);
  };

  const onClusterRegionSelected = (
    isCluster: boolean,
    isRegion: boolean,
    selectedOption: string,
    isPrimaryCluster: boolean
  ) => {
    setIsPrimaryCluster(isPrimaryCluster);
    if (selectedOption === ALL_REGIONS) {
      setClusterRegionItem(ALL_REGIONS);
      setCluster(ALL);
      setRegion(ALL);
    }

    if (isCluster || isRegion) {
      setClusterRegionItem(selectedOption);

      if (isCluster) {
        setCluster(selectedOption);
        setRegion('');
      }

      if (isRegion) {
        setRegion(selectedOption);
        setCluster('');
      }
    }
  };

  const onZoneNodeSelected = (isZone: boolean, isNode: boolean, selectedOption: string) => {
    if (selectedOption === ALL_ZONES) {
      setZoneNodeItem(ALL_ZONES);
      setZone(ALL);
      setNode(ALL);
    }

    if (isZone || isNode) {
      setZoneNodeItem(selectedOption);

      if (isZone) {
        setZone(selectedOption);
        setNode('');
      }

      if (isNode) {
        setZone('');
        setNode(selectedOption);
      }
    }
  };

  const onStartDateChange = (e: ChangeEvent<HTMLInputElement>) => {
    setStartDateTime(new Date(e.target.value));
  };

  const onEndDateChange = (e: ChangeEvent<HTMLInputElement>) => {
    setEndDateTime(new Date(e.target.value));
  };

  const handleOpenBox = (metricName: string) => {
    let openTilesCopy = [...openTiles];

    if (!openTilesCopy.includes(metricName)) {
      openTilesCopy.push(metricName);
      setOpenTiles(openTilesCopy);
    } else if (openTilesCopy.includes(metricName)) {
      const openTileIndex = openTilesCopy.indexOf(metricName);
      if (openTileIndex >= 0) {
        openTilesCopy.splice(openTileIndex, 1);
      }
      setOpenTiles(openTilesCopy);
    }
  };

  const renderSupportingGraphs = (
    metricData: any,
    uniqueOperations: any,
    groupByOperations: any,
    graphType: GraphType
  ) => {
    return (
      <Box mt={3} mr={8}>
        <SecondaryDashboard
          metricData={metricData}
          metricKey={
            metricData.name?.startsWith('active_session_history')
              ? `${metricData.name}-${Math.random() * 1000}`
              : metricData.name
          }
          containerWidth={null}
          prometheusQueryEnabled={true}
          metricMeasure={metricMeasure}
          operations={uniqueOperations}
          groupByOperations={groupByOperations}
          shouldAbbreviateTraceName={true}
          isMetricLoading={false}
          anomalyData={anomalyData}
          appName={appName}
          timezone={timezone}
          graphType={graphType}
          queryData={universeQueryData}
          onSelectAshLabel={onSelectAshLabel}
        />
      </Box>
    );
  };

  const getAshOperations = (metricData: any) => {
    let uniqueOperations: any = new Set();
    let defaultGroupBy: any = {};
    const defaultGroupByLabel = metricData.layout.metadata?.currentGroupBy?.[0];
    const param = graphQueryParams.find(
      (queryParam: any, paramIdx: number) => paramIdx > 0 && queryParam.name === metricData.name
    );
    metricData.layout?.metadata?.supportedGroupBy?.map((groupBy: any) => {
      if (groupBy.label === defaultGroupByLabel) {
        defaultGroupBy = groupBy;
      }
      // TODO: Next iteration, display query as well
      // if (!(groupBy.label === GraphLabel.QUERY_ID && isNonEmptyArray(param.filters?.queryId))) {
      if (!(groupBy.label === GraphLabel.QUERY_ID)) {
        uniqueOperations.add(groupBy.name);
      }
    });

    uniqueOperations = Array.from(uniqueOperations);

    // if (param.name === 'active_session_history' && isEmptyArray(param.groupBy)) {
    if (isEmptyArray(param.groupBy)) {
      uniqueOperations.sort((a: string, b: string) => {
        return a == defaultGroupBy.name ? -1 : b == defaultGroupBy.name ? 1 : 0;
      });
    }

    return uniqueOperations;
  };

  const getOperations = (metricData: any, graphType: GraphType) => {
    let uniqueOperations: any = new Set();
    let groupByOperations: any = new Set();
    const isOutlier =
      metricMeasure === MetricMeasure.OUTLIER || metricMeasure === MetricMeasure.OUTLIER_TABLES;
    if (
      metricData?.layout?.type === ASH &&
      isNonEmptyObject(metricData) &&
      isOutlier &&
      graphType === GraphType.SUPPORTING
    ) {
      groupByOperations = getAshOperations(metricData);
    } else {
      groupByOperations = Array.from(groupByOperations);
    }

    if (isOutlier && isNonEmptyObject(metricData)) {
      metricData.data.forEach((metricItem: any) => {
        uniqueOperations.add(metricItem.name);
      });
      uniqueOperations = Array.from(uniqueOperations);
    } else if (metricData?.layout?.type === ASH && isNonEmptyObject(metricData)) {
      uniqueOperations = getAshOperations(metricData);
      if (!uniqueOperations) {
        uniqueOperations = Array.from(new Set());
      }
    }

    return { uniqueOperations, groupByOperations };
  };

  return (
    <Box>
      <SecondaryDashboardHeader
        appName={appName}
        universeData={universeData}
        clusterRegionItem={clusterRegionItem}
        zoneNodeItem={zoneNodeItem}
        isPrimaryCluster={isPrimaryCluster}
        cluster={cluster}
        region={region}
        zone={zone}
        node={node}
        metricMeasure={metricMeasure}
        outlierType={outlierType}
        filterDuration={filterDuration}
        numNodes={numNodes}
        startDateTime={startDateTime}
        endDateTime={endDateTime}
        anomalyData={anomalyData}
        onZoneNodeSelected={onZoneNodeSelected}
        onClusterRegionSelected={onClusterRegionSelected}
        onOutlierTypeSelected={onOutlierTypeSelected}
        onSplitTypeSelected={onSplitTypeSelected}
        onNumNodesChanged={onNumNodesChanged}
        onSelectedFilterDuration={onSelectedFilterDuration}
        onStartDateChange={onStartDateChange}
        onEndDateChange={onEndDateChange}
        timezone={timezone}
      />
      <YBPanelItem
        body={
          <>
            {isNonEmptyArray(graphData) &&
              isNonEmptyArray(anomalyData?.mainGraphs) &&
              anomalyData?.mainGraphs.map((graph: any, graphIdx: number) => {
                const metricData = graphData.find((data: any) => data.name === graph.name);
                // ASH can have buttons (operations) in OVERALL, but it should not have any controls if it is the MAIN graph
                const operations =
                  metricMeasure === MetricMeasure.OVERALL
                    ? { uniqueOperations: [], groupByOperations: [] }
                    : getOperations(metricData, GraphType.MAIN);

                return (
                  <Box className={classes.secondaryDashboard}>
                    {graphIdx === 0 && (
                      <Box mt={1} ml={0.5}>
                        <span className={clsx(classes.largeBold)}>
                          {`${anomalyData?.category} Issue: ${anomalyData?.summary} `}
                        </span>
                      </Box>
                    )}
                    {renderSupportingGraphs(
                      metricData,
                      operations.uniqueOperations,
                      operations.groupByOperations,
                      GraphType.MAIN
                    )}
                  </Box>
                );
              })}
            {isNonEmptyArray(graphData) &&
              // Display metrics in the same order based on request params tp graph
              // This will help us to group metrics together based on RCA Guidelines
              recommendationMetrics?.map((reason: any, reasonIdx: number) => {
                let renderItems: any = [];
                if (isEmptyArray(reason?.name)) {
                  return (
                    <Box
                      onClick={() => handleOpenBox(reason.cause)}
                      className={classes.secondaryDashboard}
                      key={reason.cause}
                    >
                      <Box>
                        <span className={classes.smallBold}>{reason.cause}</span>
                      </Box>
                      <Box mt={1}>
                        <span className={classes.mediumNormal}>{reason.description}</span>
                      </Box>
                      {openTiles.includes(reason.cause) ? (
                        <img src={TraingleDownIcon} alt="expand" className={classes.arrowIcon} />
                      ) : (
                        <img src={TraingleUpIcon} alt="shrink" className={classes.arrowIcon} />
                      )}
                      {openTiles.includes(reason.cause) && (
                        <Box mt={3}>
                          <span className={classes.smallNormal}>
                            {'THERE ARE NO SUPPORTING METRICS'}
                          </span>
                        </Box>
                      )}
                    </Box>
                  );
                } else {
                  return reason?.name?.map((metricName: string, idx: number) => {
                    const numReasons = reason.name.length - 1;
                    const isOnlyReason = reason.name.length === 1;
                    const metricData = graphData.find(
                      (data: any, metricIdx: number) => metricIdx > 0 && data.name === metricName
                    );

                    if (isNonEmptyString(metricData?.errorMessage)) {
                      return <Box>{}</Box>;
                    } else {
                      const operations = getOperations(metricData, GraphType.SUPPORTING);

                      return (
                        <>
                          {idx === 0 && reasonIdx === 0 && (
                            <Box mt={2} mb={2}>
                              <Typography variant="h4">{'Possible Causes'}</Typography>
                            </Box>
                          )}
                          {isNonEmptyObject(metricData) && (
                            <>
                              <Box hidden={true}>
                                {renderItems.push(
                                  renderSupportingGraphs(
                                    metricData,
                                    operations.uniqueOperations,
                                    operations.groupByOperations,
                                    isOnlyReason ? GraphType.MAIN : GraphType.SUPPORTING
                                  )
                                )}
                              </Box>
                              {idx === numReasons && (
                                <Box
                                  onClick={() => handleOpenBox(metricData.name)}
                                  className={classes.secondaryDashboard}
                                  key={metricData.name}
                                >
                                  <Box>
                                    <span className={classes.smallBold}>{reason.cause}</span>
                                  </Box>
                                  <Box mt={1}>
                                    <span className={classes.mediumNormal}>
                                      {reason.description}
                                    </span>
                                  </Box>
                                  {openTiles.includes(metricData.name) ? (
                                    <img
                                      src={TraingleDownIcon}
                                      alt="expand"
                                      className={classes.arrowIcon}
                                    />
                                  ) : (
                                    <img
                                      src={TraingleUpIcon}
                                      alt="shrink"
                                      className={classes.arrowIcon}
                                    />
                                  )}
                                  {openTiles.includes(metricData.name) && (
                                    <Box mt={3}>
                                      <span className={classes.smallNormal}>
                                        {'SUPPORTING METRICS'}
                                      </span>
                                    </Box>
                                  )}
                                  {openTiles.includes(metricData.name) && (
                                    <Box className={clsx(classes.metricGroupItems)}>
                                      {renderItems?.map((item: any) => {
                                        return item;
                                      })}
                                    </Box>
                                  )}
                                </Box>
                              )}
                            </>
                          )}
                        </>
                      );
                    }
                  });
                }
              })}
          </>
        }
      />
    </Box>
  );
};
