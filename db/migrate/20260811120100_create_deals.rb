class CreateDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :deals do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :deal_stage_id, null: false
      t.bigint :assignee_id
      t.string :title, null: false
      t.text :description
      t.bigint :value_cents, null: false, default: 0
      t.string :currency, null: false, default: 'BRL'
      t.integer :temperature, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.date :expected_close_on
      t.datetime :next_action_at
      t.string :next_action
      t.datetime :closed_at
      t.text :lost_reason

      t.timestamps
    end

    add_deal_indexes
  end

  private

  def add_deal_indexes
    add_index :deals, [:account_id, :deal_stage_id, :position]
    add_index :deals, :contact_id
    add_index :deals, :assignee_id
    add_index :deals, [:account_id, :next_action_at]
  end
end
