class CreateDealStages < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_stages do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :color, null: false, default: '#6B7280'
      t.integer :position, null: false, default: 0
      t.integer :stage_type, null: false, default: 0

      t.timestamps
    end

    add_index :deal_stages, [:account_id, :position]
  end
end
