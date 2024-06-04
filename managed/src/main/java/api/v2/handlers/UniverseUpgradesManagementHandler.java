// Copyright (c) Yugabyte, Inc.
package api.v2.handlers;

import api.v2.mappers.UniverseDefinitionTaskParamsMapper;
import api.v2.mappers.UniverseEditGFlagsMapper;
import api.v2.mappers.UniverseSoftwareUpgradeStartMapper;
import api.v2.models.UniverseEditGFlags;
import api.v2.models.UniverseSoftwareUpgradeStart;
import api.v2.models.YBATask;
import api.v2.utils.ApiControllerUtils;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.yugabyte.yw.common.Util;
import com.yugabyte.yw.controllers.handlers.UpgradeUniverseHandler;
import com.yugabyte.yw.forms.GFlagsUpgradeParams;
import com.yugabyte.yw.forms.SoftwareUpgradeParams;
import com.yugabyte.yw.models.Customer;
import com.yugabyte.yw.models.Universe;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import play.mvc.Http;

@Singleton
@Slf4j
public class UniverseUpgradesManagementHandler extends ApiControllerUtils {
  @Inject public UpgradeUniverseHandler v1Handler;

  public YBATask editGFlags(
      Http.Request request, UUID cUUID, UUID uniUUID, UniverseEditGFlags editGFlags)
      throws JsonProcessingException {
    log.info("Starting v2 edit GFlags with {}", editGFlags);

    // get universe from db
    Customer customer = Customer.getOrBadRequest(cUUID);
    Universe universe = Universe.getOrBadRequest(uniUUID, customer);
    GFlagsUpgradeParams v1Params = null;
    if (Util.isKubernetesBasedUniverse(universe)) {
      v1Params =
          UniverseDefinitionTaskParamsMapper.INSTANCE.toKubernetesGFlagsUpgradeParams(
              universe.getUniverseDetails());
    } else {
      v1Params =
          UniverseDefinitionTaskParamsMapper.INSTANCE.toGFlagsUpgradeParams(
              universe.getUniverseDetails());
    }
    // fill in SpecificGFlags from universeGFlags params into v1Params
    UniverseEditGFlagsMapper.INSTANCE.copyToV1GFlagsUpgradeParams(editGFlags, v1Params);
    // invoke v1 upgrade api UpgradeUniverseHandler.upgradeGFlags
    UUID taskUuid = v1Handler.upgradeGFlags(v1Params, customer, universe);
    // construct a v2 Task to return from here
    YBATask YBATask = new YBATask().taskUuid(taskUuid).resourceUuid(universe.getUniverseUUID());

    log.info("Started gflags upgrade task {}", mapper.writeValueAsString(YBATask));
    return YBATask;
  }

  public YBATask startSoftwareUpgrade(
      Http.Request request, UUID cUUID, UUID uniUUID, UniverseSoftwareUpgradeStart upgradeStart)
      throws JsonProcessingException {
    Customer customer = Customer.getOrBadRequest(cUUID);
    Universe universe = Universe.getOrBadRequest(uniUUID, customer);

    SoftwareUpgradeParams v1Params =
        UniverseDefinitionTaskParamsMapper.INSTANCE.toSoftwareUpgradeParams(
            universe.getUniverseDetails());

    UniverseSoftwareUpgradeStartMapper.INSTANCE.copyToV1SoftwareUpgradeParams(
        upgradeStart, v1Params);

    UUID taskUuid = null;
    if (upgradeStart.getAllowRollback()) {
      taskUuid = v1Handler.upgradeDBVersion(v1Params, customer, universe);
    } else {
      taskUuid = v1Handler.upgradeSoftware(v1Params, customer, universe);
    }
    // construct a v2 Task to return from here
    YBATask ybaTask = new YBATask().taskUuid(taskUuid).resourceUuid(universe.getUniverseUUID());

    log.info("Started software upgrade task {}", mapper.writeValueAsString(ybaTask));
    return ybaTask;
  }
}
