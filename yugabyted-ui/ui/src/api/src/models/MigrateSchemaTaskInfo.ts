// tslint:disable
/**
 * Yugabyte Cloud
 * YugabyteDB as a Service
 *
 * The version of the OpenAPI document: v1
 * Contact: support@yugabyte.com
 *
 * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
 * https://openapi-generator.tech
 * Do not edit the class manually.
 */


// eslint-disable-next-line no-duplicate-imports
import type { SchemaAnalysisReport } from './SchemaAnalysisReport';


/**
 * Voyager data migration metrics details
 * @export
 * @interface MigrateSchemaTaskInfo
 */
export interface MigrateSchemaTaskInfo  {
  /**
   * 
   * @type {string}
   * @memberof MigrateSchemaTaskInfo
   */
  migration_uuid?: string;
  /**
   * 
   * @type {string}
   * @memberof MigrateSchemaTaskInfo
   */
  overall_status?: string;
  /**
   * 
   * @type {string}
   * @memberof MigrateSchemaTaskInfo
   */
  export_schema?: string;
  /**
   * 
   * @type {string}
   * @memberof MigrateSchemaTaskInfo
   */
  analyze_schema?: string;
  /**
   * 
   * @type {string}
   * @memberof MigrateSchemaTaskInfo
   */
  import_schema?: string;
  /**
   * 
   * @type {SchemaAnalysisReport}
   * @memberof MigrateSchemaTaskInfo
   */
  current_analysis_report?: SchemaAnalysisReport;
  /**
   * 
   * @type {SchemaAnalysisReport[]}
   * @memberof MigrateSchemaTaskInfo
   */
  analysis_history?: SchemaAnalysisReport[];
}



