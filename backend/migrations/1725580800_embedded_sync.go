package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/models/schema"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	syncCollectionID = "dm_sync_states1"
)

func init() {
	migrations.Register(func(db dbx.Builder) error {
		dao := daos.New(db)
		// PocketBase's system migrations provide the default users auth
		// collection. Resolve its ID rather than coupling this migration to it.
		users, err := dao.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		ownerRule := "owner = @request.auth.id"
		createRule := "@request.data.owner = @request.auth.id"
		syncStates := &models.Collection{
			BaseModel: models.BaseModel{Id: syncCollectionID},
			Name:      "sync_states",
			Type:      models.CollectionTypeBase,
			Schema: schema.NewSchema(
				&schema.SchemaField{Id: "dm_sync_owner01", Name: "owner", Type: schema.FieldTypeRelation, Required: true, Options: &schema.RelationOptions{CollectionId: users.Id, MaxSelect: types.Pointer(1)}},
				&schema.SchemaField{Id: "dm_sync_cursor01", Name: "cursor", Type: schema.FieldTypeNumber, Required: true, Options: &schema.NumberOptions{Min: types.Pointer(float64(0)), NoDecimal: true}},
				&schema.SchemaField{Id: "dm_sync_items001", Name: "items", Type: schema.FieldTypeJson, Options: &schema.JsonOptions{MaxSize: 10 << 20}},
			),
			Indexes:    types.JsonArray[string]{"CREATE UNIQUE INDEX idx_sync_states_owner ON sync_states (owner)"},
			ListRule:   &ownerRule,
			ViewRule:   &ownerRule,
			CreateRule: &createRule,
			UpdateRule: &ownerRule,
			DeleteRule: &ownerRule,
		}
		return dao.SaveCollection(syncStates)
	}, func(db dbx.Builder) error {
		dao := daos.New(db)
		collection, err := dao.FindCollectionByNameOrId(syncCollectionID)
		if err != nil {
			return nil
		}
		return dao.DeleteCollection(collection)
	})
}
