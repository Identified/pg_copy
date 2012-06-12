# PgCopy
require 'csv'

module PgCopy
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
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
        given_attrs = rows.first.keys
        if given_attrs.include?('id')
          has_nil = rows.first['id'].nil?
          given_attrs.delete('id') if has_nil
          rows.map! do |row|
            if row['id'].nil?
              row.delete('id')
            end
            if row['id'].nil? != has_nil
              raise "ALL IDs must be nil or all IDs must be not nil"
            end
            row
          end
        end

        # Be sure that we retrieve attributes in the correct order.
        def get_attributes(row, given_attrs)
          given_attrs.collect { |x| row[x] }
        end

        Tempfile.open('sql_buffer') do |file_handle|
          rows.each do |row|
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

ActiveRecord::Base.send(:include, PgCopy)
