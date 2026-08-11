class CreateDealActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_activities do |t|
      t.bigint :account_id, null: false
      t.bigint :deal_id, null: false
      t.bigint :user_id
      t.integer :activity_type, null: false, default: 0
      t.text :content
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :deal_activities, [:deal_id, :created_at]
    add_index :deal_activities, :account_id
  end
end
