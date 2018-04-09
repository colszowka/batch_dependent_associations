RSpec.describe BatchDependentAssociations do
  it "has a version number" do
    expect(BatchDependentAssociations::VERSION).not_to be nil
  end

  describe "unsafe model without batching" do
    after do
      UnsafePerson.destroy_all
    end

    context "1 associated entity" do
      it "executes one select" do
        persist_with_associations(clazz: UnsafePerson, association_clazz: BankAccount, association_count: 1)
        expect { UnsafePerson.first.destroy }.to make_database_queries(count: 1, matching: /SELECT "bank_accounts"/)
      end
    end

    context "10 associated entity" do
      it "executes one select" do
        persist_with_associations(clazz: UnsafePerson, association_clazz: BankAccount, association_count: 10)
        expect { UnsafePerson.first.destroy }.to make_database_queries(count: 1, matching: /SELECT "bank_accounts"/)
      end
    end
  end
end

def persist_with_associations(clazz:, association_clazz:, association_count:)
  instance = clazz.create!
  association_count.times do
    association_clazz.create!(person_id: instance.id)
  end
end
