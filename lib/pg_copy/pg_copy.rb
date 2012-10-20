# PgCopy
require 'csv'

module PgCopy
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def reserve_ids limit = 1
      self.connection.execute("select nextval('#{self.table_name}_id_seq'::regclass) from generate_series(1, #{limit})").map{|r| r["nextval"]}
    end

    def bulk_create
      Thread.current[:bulk_create] ||= {}
      bulk_create_klass_count = Thread.current[:bulk_create].keys.length
      begin
        Thread.current[:bulk_create][self] ||= []
        ActiveRecord::Persistence.class_eval do
          alias :old_create :create
          def create
            if Thread.current[:bulk_create].select{|k,v| self.is_a?(k)}.any?
              Thread.current[:bulk_create][self.class] ||= []
              Thread.current[:bulk_create][self.class] << self unless @bulk_created
              @bulk_created = true
            else
              old_create
            end
          end
        end

        self.transaction do
          yield

          Thread.current[:bulk_create] = Thread.current[:bulk_create].delete_if do |klass, rows|
              klass.pg_copy(rows.map(&:attributes)) if rows.any? and rows.first.is_a?(self)
          end
        end

        ActiveRecord::Persistence.class_eval do
          alias :create     :old_create
        end

      ensure
        Thread.current[:bulk_create] = Thread.current[:bulk_create].delete_if do |klass, rows|
          self == klass or klass.ancestors.include?(self)
        end
      end

      if bulk_create_klass_count != Thread.current[:bulk_create].keys.length
        raise "PgCopy#bulk_create run in class #{self}, expected bulk_create_klass_count to equal #{bulk_create_klass_count} but was #{Thread.current[:bulk_create].keys.length}"
      end

    end

    def bulk_destroy
      Thread.current[:bulk_destroy] ||= {}
      bulk_destroy_klass_count = Thread.current[:bulk_destroy].keys.length
      begin
        Thread.current[:bulk_destroy][self] ||= []
        ActiveRecord::Persistence.class_eval do
          private
          # TODO: once we can upgrade to > rails 3.2.3, we can override "destroy_row" instead which will allow us to remove things marked below
          alias :old_destroy :destroy
          def destroy
            if Thread.current[:bulk_destroy].select{|k,v| self.is_a?(k)}.any?
              # TODO: remove based on above comment
              destroy_associations

              Thread.current[:bulk_destroy][self.class] ||= []
              Thread.current[:bulk_destroy][self.class] << self unless @bulk_destroyed
              @bulk_destroyed = true

              # TODO: remove based on above comment
              @destroyed = true
              freeze
            else
              old_destroy
            end
          end
        end

        self.transaction do
          yield

          Thread.current[:bulk_destroy] = Thread.current[:bulk_destroy].delete_if do |klass, rows|
              klass.delete_all(:id => rows.map(&:id)) if rows.any? and rows.first.is_a?(self)
          end
        end

        ActiveRecord::Persistence.class_eval do
          alias :destroy     :old_destroy
        end

      ensure
        Thread.current[:bulk_destroy] = Thread.current[:bulk_destroy].delete_if do |klass, rows|
          self == klass or klass.ancestors.include?(self)
        end
      end

      if bulk_destroy_klass_count != Thread.current[:bulk_destroy].keys.length
        raise "PgCopy#bulk_destroy run in class #{self}, expected bulk_destroy_klass_count to equal #{bulk_destroy_klass_count} but was #{Thread.current[:bulk_destroy].keys.length}"
      end

    end

    # Rows should be an array of hashes, each hash should contain the
    # same keys, the first element in the array will be used to
    # deterimine the keys for copying.  The values in the other hashes
    # will be the data passed into COPY.
    #
    # See README for additional documentation.
    #
    # PGError will be raised in the event of a failed copy.
    def pg_copy(rows=nil)
      if rows.nil? and block_given?
        rows = yield
      end

      if rows and rows.any?
        with_id = rows.select{|r| r['id']}
        without_id = rows.select{|r| r['id'].nil?}
        if without_id.any?
          rows.map! do |row|
            if row['id'].nil?
              row.delete('id')
            end
            row
          end
        end
        @serialized_attributes_keys = serialized_attributes.keys
        # Be sure that we retrieve attributes in the correct order.
        def get_attributes(row, given_attrs)
          given_attrs.collect do |x|
            row[x] = serialized_attributes[x].dump(row[x]) if @serialized_attributes_keys.include? x
            row[x]
          end
        end
        [with_id, without_id].each do |row_set|
          if row_set.any?
            given_attrs = row_set.first.keys
            Tempfile.open('sql_buffer') do |file_handle|
              row_set.each do |row|
                line = CSV.generate_line(get_attributes(row, given_attrs))
                file_handle.write line
              end

              file_handle.close
              table_name = self.table_name
              copy_string = "copy #{table_name} (#{given_attrs.join(', ')}) from stdin csv"
              ms = Benchmark.ms  do
                ActiveRecord::Base.connection.execute copy_string
                ActiveRecord::Base.connection.raw_connection.put_copy_data file_handle.open.read
                ActiveRecord::Base.connection.raw_connection.put_copy_end
                ActiveRecord::Base.connection.raw_connection.get_last_result
              end
              ActiveRecord::Base.connection.logger.info ["#{rows.length} rows", "COPY #{table_name}", ms].join(", ")
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, PgCopy)
