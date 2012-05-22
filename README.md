PgCopy
======

Add pg_copy class method to ActiveRecord::Base to provide PostgreSQL
COPY support for faster bulk insertion of data.  

It is assumed that you wish to create instances of the base class
called from, and you must provide an Array of Hashes to be inserted.

Installing
======

Add this to your Gemfile:

```
gem 'pg_copy', git: 'git@github.com:Identified/pg_copy.git'
```

Example
=======

Model.pg_copy([{'first_attr_name'=>'first_attr_val1', 
                'second_attr_name'=>'second_attr_val1'},
               {'first_attr_name'=>'first_attr_val2',
                'second_attr_name'=>'second_attr_val2'}])

You can also supply a block to supply values to be COPY'd, but it has
no real benefits other than looking a bit prettier.

This will create two rows using the PostgreSQL COPY command assuming
that all PostgreSQL required values for Model are supplied and all
unique indexes are satisfied.  Note that no ActiveRecord callbacks
will be called nor will any ActiveRecord validation be done.

In case any of the rows cannot be inserted, (most commonly due to a
uniqueness constraint) a PGError exception will be raised.  failure
cases the entire COPY operation is aborted and thus NO DATA will be
inserted at all, as described in the PostgreSQL documentation on COPY.

Future enhancements
===================

Allow for bulk insertion of so many records that cannot fit in memory
by allowing support for constructing rows just-in-time.

Copyright (c) 2010 [Osbert Feng], released under the MIT license
