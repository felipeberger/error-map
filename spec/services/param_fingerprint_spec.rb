require "rails_helper"

RSpec.describe ParamFingerprint do
  it "matches for payloads with the same structure but different values" do
    a = described_class.compute({ "user" => { "id" => 1, "name" => "Ada" } })
    b = described_class.compute({ "user" => { "id" => 99, "name" => "Grace" } })

    expect(a).to eq(b)
  end

  it "is insensitive to key order" do
    a = described_class.compute({ "a" => 1, "b" => "x" })
    b = described_class.compute({ "b" => "y", "a" => 2 })

    expect(a).to eq(b)
  end

  it "differs when a field is missing" do
    a = described_class.compute({ "user" => { "id" => 1, "name" => "Ada" } })
    b = described_class.compute({ "user" => { "id" => 1 } })

    expect(a).not_to eq(b)
  end

  it "differs when a value type changes" do
    a = described_class.compute({ "user" => { "id" => 1 } })
    b = described_class.compute({ "user" => { "id" => "1" } })

    expect(a).not_to eq(b)
  end
end
