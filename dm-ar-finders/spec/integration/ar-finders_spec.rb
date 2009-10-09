require 'spec_helper'

if HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES
  describe "DataMapper::Resource" do
    after do
      DataMapper.repository(:default).adapter.execute('DELETE from green_smoothies');
      DataMapper.repository(:default).adapter.execute('DELETE from customers');
    end

    before(:all) do
      class ::Customer
        property :id, Serial
        property :first_name, String
        property :last_name, String
        property :hometown, String

        auto_migrate!(:default)
      end
      class ::GreenSmoothie
        include DataMapper::Resource
        property :id, Serial
        property :name, String
        property :customer_id, Integer
        belongs_to :customer

        auto_migrate!(:default)
      end
    end

    it "should find/create using find_or_create" do
      DataMapper.repository(:default) do
        green_smoothie = GreenSmoothie.new(:name => 'Banana')
        green_smoothie.save
        GreenSmoothie.find_or_create({:name => 'Banana'}).id.should eql(green_smoothie.id)
        GreenSmoothie.find_or_create({:name => 'Strawberry'}).id.should eql(2)
      end
    end

    it "should use find_by and use the name attribute to find a record" do
      DataMapper.repository(:default) do
        green_smoothie = GreenSmoothie.create({:name => 'Banana'})
        green_smoothie.should == GreenSmoothie.find_by_name('Banana')
      end
    end

    it "should use find_all_by to find records using an attribute" do
      DataMapper.repository(:default) do
        green_smoothie = GreenSmoothie.create({:name => 'Banana'})
        green_smoothie2 = GreenSmoothie.create({:name => 'Banana'})
        found_records = GreenSmoothie.find_all_by_name('Banana')
        found_records.length.should == 2
        found_records.each do |found_record|
          [green_smoothie, green_smoothie2].include?(found_record).should be_true
        end
      end
    end
    
    it "should load associations via find_or_create" do
      DataMapper.repository(:default) do
        customer = Customer.new(:first_name => 'Jerry', :last_name => 'Cantrell', :hometown => 'Seattle')
        customer.save
        GreenSmoothie.find_or_create({:first_name => 'Jerry', :last_name => 'Cantrell', :hometown => 'Seattle'}).id.should eql(customer.id)
        customer2 = GreenSmoothie.find_or_create({:first_name => 'Layne', :last_name => 'Staley', :hometown => 'Seattle'})
        customer2.id.should eql(2)

        green_smoothie = GreenSmoothie.new(:name => 'Banana', :customer_id => customer.id)
        green_smoothie.save
        banana = GreenSmoothie.find_or_create({:name => 'Banana', :customer_id => customer.id})
        banana.id.should eql(green_smoothie.id)
        banana.customer.should == customer

        strawberry = GreenSmoothie.find_or_create({:name => 'Strawberry', :customer_id => customer2.id})
        strawberry.id.should eql(2)
        strawberry.customer.should == customer2
      end
    end

    

    ###

    describe '#find_by_sql' do
      before(:each) do
        DataMapper.repository(:default) do
          @customer1 = Customer.create(:first_name => 'Jerry', :last_name => 'Cantrell', :hometown => 'Seattle')
          @customer2 = Customer.create(:first_name => 'Layne', :last_name => 'Staley', :hometown => 'Seattle')

          @banana = GreenSmoothie.create(:name => 'Banana', :customer_id => @customer1.id)
          @blueberry =  GreenSmoothie.create(:name => 'Blueberry', :customer_id => @customer2.id)
        end
      end

      it 'should find the resource when given a string' do
        DataMapper.repository(:default) do
          found = GreenSmoothie.find_by_sql <<-SQL
            SELECT id, name FROM green_smoothies WHERE id = 1
          SQL

          found.should_not be_empty
          found.first.should == @banana
        end
      end

      it 'should find the resource when given an array containing SQL and bind values' do
        DataMapper.repository(:default) do
          found = GreenSmoothie.find_by_sql [<<-SQL, @banana.id]
            SELECT id, name FROM green_smoothies WHERE id = ?
          SQL

          found.should_not be_empty
          found.first.should == @banana
        end
      end

      it 'should return an empty collection when nothing is found' do
        DataMapper.repository(:default) do
          found = GreenSmoothie.find_by_sql [<<-SQL, 0]
            SELECT id, name FROM green_smoothies WHERE id = ?
          SQL

          found.should be_kind_of(DataMapper::Collection)
          found.should be_empty
        end
      end

      it 'should raise an error if no SQL string or Query is given' do
        DataMapper.repository(:default) do
          lambda { GreenSmoothie.find_by_sql nil }.should raise_error(ArgumentError, /requires a query/)
        end
      end

      it 'should raise an error if an unacceptable argument is given' do
        DataMapper.repository(:default) do
          lambda { GreenSmoothie.find_by_sql :go }.should raise_error(ArgumentError)
        end
      end

      it 'should accept a Query instance' do
        query = GreenSmoothie.find_by_sql([<<-SQL, @banana.id]).query
          SELECT id, name FROM green_smoothies WHERE id = ?
        SQL

        found = GreenSmoothie.find_by_sql(query)
        found.should_not be_empty
        found.first.should == @banana
      end

      # Options.

      describe ':repository option' do
        it 'should use repository identified by the given symbol' do
          found = GreenSmoothie.find_by_sql <<-SQL, :repository => ENV['ADAPTER'].intern
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          found.repository.should == DataMapper.repository(ENV['ADAPTER'].intern)
        end

        it 'should use the default repository if no repository option is specified' do
          found = GreenSmoothie.find_by_sql <<-SQL
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          found.repository.should == DataMapper.repository(:default)
        end
      end

      describe ':reload option' do
        it 'should reload existing resources in the identity map if given true' do
          found = GreenSmoothie.find_by_sql <<-SQL, :reload => true
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          found.query.reload?.should be_true
        end

        it 'should not reload existing resources in the identity map if given false' do
          found = GreenSmoothie.find_by_sql <<-SQL, :reload => false
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          found.query.reload?.should be_false
        end

        it 'should default to false' do
          found = GreenSmoothie.find_by_sql <<-SQL
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          found.query.reload?.should be_false
        end
      end

      describe ':properties option' do
        it 'should accept an array of symbols' do
          properties = GreenSmoothie.properties

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => properties.map { |property| property.name }
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first
          properties.each { |property| property.should be_loaded(resource) }
        end

        it 'should accept a single Symbol' do
          property = GreenSmoothie.properties[:id]

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => property.name
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first

          property.should be_loaded(resource)
          GreenSmoothie.properties[:name].should_not be_loaded(resource)
        end

        it 'should accept a PropertySet' do
          properties = GreenSmoothie.properties

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => properties
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first
          properties.each { |property| property.should be_loaded(resource) }
        end

        it 'should accept a single property' do
          property = GreenSmoothie.properties[:id]

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => property
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first

          property.should be_loaded(resource)
          GreenSmoothie.properties[:name].should_not be_loaded(resource)
        end

        it 'should accept an array of Properties' do
          properties = GreenSmoothie.properties.to_a

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => properties
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first
          properties.each { |property| property.should be_loaded(resource) }
        end

        it 'should use the given properties in preference over those in the SQL query' do
          properties = GreenSmoothie.properties

          found = GreenSmoothie.find_by_sql <<-SQL, :properties => properties
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first
          properties.each { |property| property.should be_loaded(resource) }
        end

        it 'should use the default properties if none are specified' do
          found = GreenSmoothie.find_by_sql <<-SQL
            SELECT id, name FROM green_smoothies LIMIT 1
          SQL

          resource = found.first
          GreenSmoothie.properties.each { |property| property.should be_loaded(resource) }
        end

        it 'should correctly map reordered properties from the query' do
          DataMapper.repository(:default) do
            found = GreenSmoothie.find_by_sql([<<-SQL, @banana.id], :properties => [:name, :id])
              SELECT name, id FROM green_smoothies WHERE id = ?
            SQL

            found.should_not be_empty
            found.first.id.should == @banana.id
            found.first.should == @banana
          end
        end

        it 'should correctly map joined properties from the query' do
          DataMapper.repository(:default) do
            found = GreenSmoothie.find_by_sql([%(
              SELECT s.name, s.id, c.first_name, c.last_name
                FROM green_smoothies s, customers c
               WHERE id = ?
                 AND s.customer_id = c.id
            ), @banana.id],
            :properties => [:name, :id, Customer.property[:first_name], Customer.propery[:last_name]])

            found.should_not be_empty
            smoothie = found.first
            smoothie.id.should == @banana.id
            smoothie.name.should == @banana.name
            smoothie.first_name.should == @customer1.first_name
            smoothie.last_name.should  == @customer1.last_name
          end
        end
      end

      # Dynamic column enumeration (eg, not dependent on properties/fields).

      describe 'column enumeration without properties' do

        it 'should enumerate columns from the query without needing properties' do
          found = GreenSmoothie.find_by_sql [<<-SQL, @banana.id]
            SELECT name, customer_id, id FROM green_smoothies WHERE id = ?
          SQL

          found.should_not be_empty
          found.first.should == @banana
          found.first.id.should == @banana.id
          found.first.name.should == @banana.name
          found.first.customer_id.should == @banana.customer_id
        end

        it 'should enumerate columns from a join query without needing properties' do
          DataMapper.repository(:default) do
            found = GreenSmoothie.find_by_sql <<-SQL
              SELECT s.name, s.id, c.first_name, c.last_name
                FROM green_smoothies s, customers c
               WHERE s.customer_id = c.id
            SQL

            found.should_not be_empty

            banana = found.first
            banana.id.should == @banana.id
            banana.name.should == @banana.name
            banana.first_name.should == @customer1.first_name
            banana.last_name.should  == @customer1.last_name

            blueberry = found.last
            blueberry.id.should == @blueberry.id
            blueberry.name.should == @blueberry.name
            blueberry.first_name.should == @customer2.first_name
            blueberry.last_name.should  == @customer2.last_name
          end
        end

        it 'should enumerate columns from a group by query without needing properties' do
          DataMapper.repository(:default) do
            found = GreenSmoothie.find_by_sql <<-SQL
              SELECT hometown, count(id) AS num_people
                FROM customers
               GROUP BY hometown
            SQL

            found.length.should == 1
            found.first.hometown.should == @customer1.hometown
            found.first.num_people.should == 2
          end
        end


      end
    end # find_by_sql

  end
end
