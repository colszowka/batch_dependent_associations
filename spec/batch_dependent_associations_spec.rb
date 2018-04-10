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
        persist_with_associations(clazz: UnsafePerson, association_clazz: BankAccount, association_count: 9)
        expect { UnsafePerson.first.destroy }.to make_database_queries(count: 1, matching: /SELECT "bank_accounts"/)
      end
    end
  end

  describe "safe model with batching" do
    after do
      SafePerson.destroy_all
    end

    context "number of associated entities below batch limit" do
      it "executes one select" do
        persist_with_associations(clazz: SafePerson, association_clazz: BankAccount, association_count: 1)
        expect { SafePerson.first.destroy }.to make_database_queries(count: 1, matching: /SELECT  "bank_accounts"(.+) LIMIT/)
      end
    end

    context "number of associated entities above batch limit" do
      it "executes 2 selects" do
        persist_with_associations(clazz: SafePerson, association_clazz: BankAccount, association_count: 9)
        expect { SafePerson.first.destroy }.to make_database_queries(count: 2, matching: /SELECT  "bank_accounts"(.+) LIMIT/)
      end
    end

    context "number of associated entities above 2 times batch limit" do
      it "executes 3 selects" do
        persist_with_associations(clazz: SafePerson, association_clazz: BankAccount, association_count: 13)
        expect { SafePerson.first.destroy }.to make_database_queries(count: 3, matching: /SELECT  "bank_accounts"(.+) LIMIT/)
      end
    end

    context "dependent destroy" do
      it "calls destroy on associations" do
        persist_with_associations(clazz: SafePerson, association_clazz: BankAccount, association_count: 1)
        safe_person = SafePerson.first
        bank_account = double

        expect(safe_person).to receive_message_chain(:bank_accounts, :find_each).and_yield(bank_account)
        expect(bank_account).to receive(:destroy)

        safe_person.destroy
      end
    end

    context "dependent delete_all" do
      it "calls delete on associations" do
        persist_with_associations(clazz: SafePerson, association_clazz: Friend, association_count: 1)
        safe_person = SafePerson.first
        friend = double

        expect(safe_person).to receive_message_chain(:friends, :find_each).and_yield(friend)
        expect(friend).to receive(:delete)

        safe_person.destroy
      end
    end

    context "throwaway test class" do
      let(:test_class) { :Test }

      before do
        class Test < ActiveRecord::Base; end
        Test.send(:include, BatchDependentAssociations)
      end

      after do
        undefine(Object, test_class)
      end

      it "sets default batch size to 1000" do
        expect(Test.dependent_associations_batch_size).to eq(1000)
      end
  
      it "default batch size can be set" do
        Test.dependent_associations_batch_size = 5
        expect(Test.dependent_associations_batch_size).to eq(5)
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

def undefine(clazz, const)
  clazz.send(:remove_const, const) if clazz.const_defined?(const)
end
