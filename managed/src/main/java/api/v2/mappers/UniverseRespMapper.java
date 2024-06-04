// Copyright (c) YugaByte, Inc.
package api.v2.mappers;

import api.v2.models.Universe;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.time.ZoneOffset;
import org.mapstruct.DecoratedWith;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.factory.Mappers;

@DecoratedWith(UniverseRespDecorator.class)
@Mapper(
    config = CentralConfig.class,
    uses = {
      UniverseDefinitionTaskParamsMapper.class,
      CommunicationPortsMapper.class,
      ClusterMapper.class
    })
public interface UniverseRespMapper {
  UniverseRespMapper INSTANCE = Mappers.getMapper(UniverseRespMapper.class);

  @Mapping(target = "spec", source = "universeDetails.delegate")
  @Mapping(target = "info", source = "universeDetails.delegate")
  Universe toV2UniverseResp(com.yugabyte.yw.forms.UniverseResp v1UniverseResp);

  // below methods are used implicitly to generate above mapping
  default java.time.OffsetDateTime parseToOffsetDateTime(String datetime) throws ParseException {
    return new SimpleDateFormat("EEE MMM dd HH:mm:ss zzz yyyy")
        .parse(datetime)
        .toInstant()
        .atOffset(ZoneOffset.UTC);
  }
}
