require 'rails_helper'

RSpec.describe RedisLodgingService do
  let(:service) { described_class.new }
  let(:lodging_data) do
    {
      id: SecureRandom.uuid,
      title: "Paris Loft",
      description: "Beautiful view",
      price: 100,
      image_url: "https://example.com/image.jpg"
    }
  end

  before do
    # Nettoie Redis avant chaque test
    REDIS.flushdb
  end

  describe "#save_lodging" do
    it "saves lodging and can retrieve it" do
      expect(service.save_lodging(**lodging_data)).to eq(true)
      saved = service.find_lodging(lodging_data[:id])
      expect(saved[:title]).to eq("Paris Loft")
      expect(saved[:image_url]).to eq("https://example.com/image.jpg")
    end
  end

  describe "#update_lodging" do
    it "updates existing lodging" do
      service.save_lodging(**lodging_data)
      service.update_lodging(lodging_data[:id], OpenStruct.new(title: "Updated Loft"))
      updated = service.find_lodging(lodging_data[:id])
      expect(updated[:title]).to eq("Updated Loft")
    end
  end

  describe "#delete_lodging" do
    it "removes lodging from Redis" do
      service.save_lodging(**lodging_data)
      service.delete_lodging(lodging_data[:id])
      expect(service.find_lodging(lodging_data[:id])).to be_nil
    end
  end

  describe "#search_similar" do
    it "returns lodgings similar to query" do
      service.save_lodging(**lodging_data)
      results = service.search_similar("Paris")
      expect(results).not_to be_empty
      expect(results.first[:title]).to eq("Paris Loft")
    end
  end

  describe "#list_all_lodgings" do
    it "returns all lodgings" do
      service.save_lodging(**lodging_data)
      all = service.list_all_lodgings
      expect(all.size).to eq(1)
      expect(all.first[:title]).to eq("Paris Loft")
    end
  end
end
