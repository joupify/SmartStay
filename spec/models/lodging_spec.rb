require 'rails_helper'

RSpec.describe Lodging, type: :model do
  let(:valid_attributes) do
    {
      id: SecureRandom.uuid,
      title: "Appartement Paris",
      description: "Charmant T2 proche centre",
      price: 120.0,
      image_url: "https://example.com/img.jpg"
    }
  end

  describe "validations" do
    it "is valid with valid attributes" do
      lodging = Lodging.new(valid_attributes)
      expect(lodging).to be_valid
    end

    it "is invalid without a title" do
      lodging = Lodging.new(valid_attributes.merge(title: nil))
      expect(lodging).not_to be_valid
      expect(lodging.errors[:title]).to include("can't be blank")
    end

    it "is invalid with negative price" do
      lodging = Lodging.new(valid_attributes.merge(price: -10))
      expect(lodging).not_to be_valid
      expect(lodging.errors[:price]).to include("must be greater than or equal to 0")
    end
  end

  describe "#to_h" do
    it "returns a hash with correct keys" do
      lodging = Lodging.new(valid_attributes)
      expect(lodging.to_h).to include(:id, :title, :description, :price, :image_url)
    end
  end

  describe ".find" do
    let(:service) { RedisLodgingService.new }

    before do
      REDIS.flushdb
      service.save_lodging(**valid_attributes)
    end

    it "retrieves lodging from Redis" do
      lodging = Lodging.find(valid_attributes[:id])
      expect(lodging).to be_a(Lodging)
      expect(lodging.title).to eq("Appartement Paris")
      expect(lodging.image_url).to eq("https://example.com/img.jpg")
    end

    it "returns nil if lodging does not exist" do
      expect(Lodging.find("nonexistent")).to be_nil
    end
  end
end
