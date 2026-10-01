class CreateCadences < ActiveRecord::Migration[7.1]
  def change
    create_cadences
    create_cadence_enrollments
    add_cadence_indexes
  end

  private

  def create_cadences
    create_table :cadences do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :sender_id
      t.bigint :deal_stage_id
      t.string :title, null: false
      t.boolean :enabled, null: false, default: true
      t.jsonb :audience, null: false, default: []
      t.jsonb :steps, null: false, default: []

      t.timestamps
    end
  end

  def create_cadence_enrollments
    create_table :cadence_enrollments do |t|
      t.bigint :account_id, null: false
      t.bigint :cadence_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :conversation_id
      t.integer :step_index, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :deliver_at, null: false

      t.timestamps
    end
  end

  def add_cadence_indexes
    add_index :cadences, :account_id
    add_index :cadences, :deal_stage_id
    # One enrollment per contact per cadence: this is the whole idempotency story, both for the
    # audience scan that re-runs every five minutes and for never charging twice for the same send.
    add_index :cadence_enrollments, [:cadence_id, :contact_id], unique: true
    add_index :cadence_enrollments, [:status, :deliver_at]
    add_index :cadence_enrollments, :conversation_id
  end
end
