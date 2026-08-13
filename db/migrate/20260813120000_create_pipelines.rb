class CreatePipelines < ActiveRecord::Migration[7.0]
  def up
    create_table :pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :pipelines, [:account_id, :position]

    add_column :deal_stages, :pipeline_id, :bigint

    backfill_pipelines

    change_column_null :deal_stages, :pipeline_id, false
    add_index :deal_stages, [:pipeline_id, :position]
    remove_index :deal_stages, column: [:account_id, :position]
  end

  def down
    add_index :deal_stages, [:account_id, :position]
    remove_index :deal_stages, column: [:pipeline_id, :position]
    remove_column :deal_stages, :pipeline_id
    drop_table :pipelines
  end

  private

  def backfill_pipelines
    execute(<<~SQL.squish)
      INSERT INTO pipelines (account_id, name, position, created_at, updated_at)
      SELECT DISTINCT account_id, 'Funil padrão', 0, NOW(), NOW()
      FROM deal_stages
    SQL

    execute(<<~SQL.squish)
      UPDATE deal_stages
      SET pipeline_id = pipelines.id
      FROM pipelines
      WHERE pipelines.account_id = deal_stages.account_id
    SQL
  end
end
