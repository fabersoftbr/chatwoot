class CreateChannelEvolution < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_evolution do |t|
      t.integer :account_id, null: false
      t.string :identifier
      t.string :instance_id
      t.string :instance_token
      t.string :qr_code
      t.string :webhook_url
      t.jsonb :additional_attributes, default: {}
      t.timestamps

      t.index [:identifier], unique: true
    end
  end
end
