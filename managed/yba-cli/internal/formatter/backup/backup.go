/*
* Copyright (c) YugaByte, Inc.
 */

package backup

import (
	"encoding/json"
	"time"

	"github.com/sirupsen/logrus"
	ybaclient "github.com/yugabyte/platform-go-client"
	"github.com/yugabyte/yugabyte-db/managed/yba-cli/internal/formatter"
)

const (
	defaultBackupListing = "table {{.BackupUUID}}\t{{.BaseBackupUUID}}\t{{.UniverseUUID}}\t{{.UniverseName}}" +
		"\t{{.StorageConfigUUID}}\t{{.StorageConfigType}}\t{{.BackupType}}\t{{.ScheduleName}}" +
		"\t{{.HasIncrementalBackups}}\t{{.State}}\t{{.CreateTime}}\t{{.CompletionTime}}\t{{.ExpiryTime}}"

	backupUUIDHeader            = "Backup UUID"
	baseBackupUUIDHeader        = "Base Backup UUID"
	universeUUIDHeader          = "Universe UUID"
	universeNameHeader          = "Universe Name"
	storageConfigUUIDHeader     = "Storage Configuration UUID"
	storageConfigTypeHeader     = "Storage Configuration Type"
	backupTypeHeader            = "Backup Type"
	scheduleNameHeader          = "Schedule Name"
	hasIncrementalBackupsHeader = "Has Incremental Backups"
	stateHeader                 = "State"
	expiryTimeHeader            = "Expiry Time"
	createTimeHeader            = "Create Time"
	completionTimeHeader        = "Completion Time"
)

// Context for BackupResp outputs
type Context struct {
	formatter.HeaderContext
	formatter.Context
	b ybaclient.BackupResp
}

// NewBackupFormat for formatting output
func NewBackupFormat(source string) formatter.Format {
	switch source {
	case "table", "":
		format := defaultBackupListing
		return formatter.Format(format)
	default: // custom format or json or pretty
		return formatter.Format(source)
	}
}

// Write renders the context for a list of backups
func Write(ctx formatter.Context, backups []ybaclient.BackupResp) error {
	render := func(format func(subContext formatter.SubContext) error) error {
		for _, backup := range backups {
			err := format(&Context{b: backup})
			if err != nil {
				logrus.Debugf("Error rendering backup: %v", err)
				return err
			}
		}
		return nil
	}
	return ctx.Write(NewBackupContext(), render)

}

// NewBackupContext creates a new context for rendering backups
func NewBackupContext() *Context {
	backupCtx := Context{}
	backupCtx.Header = formatter.SubHeaderContext{
		"BackupUUID":            backupUUIDHeader,
		"BaseBackupUUID":        baseBackupUUIDHeader,
		"UniverseUUID":          universeUUIDHeader,
		"UniverseName":          universeNameHeader,
		"StorageConfigUUID":     storageConfigUUIDHeader,
		"StorageConfigType":     storageConfigTypeHeader,
		"BackupType":            backupTypeHeader,
		"ScheduleName":          scheduleNameHeader,
		"HasIncrementalBackups": hasIncrementalBackupsHeader,
		"State":                 stateHeader,
		"ExpiryTime":            expiryTimeHeader,
		"CreateTime":            createTimeHeader,
		"CompletionTime":        completionTimeHeader,
	}
	return &backupCtx
}

// BackupUUID fetches Backup UUID
func (c *Context) BackupUUID() string {
	return c.b.GetCommonBackupInfo().BackupUUID
}

// BaseBackupUUID fetches Base Backup UUID
func (c *Context) BaseBackupUUID() string {
	return c.b.GetCommonBackupInfo().BaseBackupUUID
}

// StorageConfigName fetches Storage Config Name
func (c *Context) StorageConfigUUID() string {
	return c.b.GetCommonBackupInfo().StorageConfigUUID
}

// ExpiryTime fetches Expiry Time
func (c *Context) ExpiryTime() string {
	expiryTime := c.b.GetExpiryTime()
	if expiryTime.IsZero() {
		return ""
	} else {
		return expiryTime.Format(time.RFC1123Z)
	}
}

// BackupType fetches Backup Type
func (c *Context) BackupType() string {
	return c.b.GetBackupType()
}

// ScheduleName fetches Schedule Name
func (c *Context) ScheduleName() string {
	return c.b.GetScheduleName()
}

// StorageConfigType fetches Storage Config Type
func (c *Context) StorageConfigType() string {
	return c.b.GetStorageConfigType()
}

// HasIncrementalBackups fetches Has Incremental Backups
func (c *Context) HasIncrementalBackups() bool {
	return c.b.HasIncrementalBackups
}

// State fetches State
func (c *Context) State() string {
	return c.b.GetCommonBackupInfo().State
}

// UniverseUUID fetches Universe UUID
func (c *Context) UniverseUUID() string {
	return c.b.GetUniverseUUID()
}

// UniverseName fetches Universe Name
func (c *Context) UniverseName() string {
	return c.b.GetUniverseName()
}

// CreateTime fetches Create Time
func (c *Context) CreateTime() string {
	return c.b.GetCommonBackupInfo().CreateTime.Format(time.RFC1123Z)
}

// CompletionTime fetches Completion Time
func (c *Context) CompletionTime() string {
	completionTime := c.b.GetCommonBackupInfo().CompletionTime
	if completionTime == nil {
		return ""
	} else {
		return completionTime.Format(time.RFC1123Z)
	}
}

// MarshalJSON function
func (c *Context) MarshalJSON() ([]byte, error) {
	return json.Marshal(c.b)
}
