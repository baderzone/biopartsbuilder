# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140408141837) do

  create_table "annotations", :force => true do |t|
    t.integer  "chromosome_id"
    t.integer  "start"
    t.integer  "end"
    t.integer  "feature_id"
    t.string   "strand"
    t.string   "systematic_name"
    t.string   "gene_name"
    t.string   "ontology_term"
    t.string   "dbxref"
    t.text     "description"
    t.string   "orf_classification"
    t.date     "gff_created_at"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
  end

  create_table "chromosomes", :force => true do |t|
    t.string   "name"
    t.integer  "organism_id"
    t.text     "seq",            :limit => 2147483647
    t.string   "genome_version"
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
  end

  create_table "constructs", :force => true do |t|
    t.integer  "design_id"
    t.string   "name"
    t.text     "seq"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text     "comment"
  end

  add_index "constructs", ["design_id"], :name => "index_constructs_on_design_id"

  create_table "designs", :force => true do |t|
    t.integer  "part_id"
    t.integer  "protocol_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.text     "comment"
  end

  add_index "designs", ["part_id"], :name => "index_designs_on_part_id"
  add_index "designs", ["protocol_id"], :name => "index_designs_on_protocol_id"

  create_table "designs_labs", :force => true do |t|
    t.integer  "lab_id"
    t.integer  "design_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "designs_labs", ["design_id"], :name => "index_designs_labs_on_design_id"
  add_index "designs_labs", ["lab_id"], :name => "index_designs_labs_on_lab_id"

  create_table "designs_orders", :force => true do |t|
    t.integer  "order_id"
    t.integer  "design_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "designs_orders", ["design_id"], :name => "index_designs_orders_on_design_id"
  add_index "designs_orders", ["order_id"], :name => "index_designs_orders_on_order_id"

  create_table "enzymes", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.string   "sequence"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "features", :force => true do |t|
    t.string   "name"
    t.text     "definition"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "file_converts", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "job_statuses", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "job_types", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "jobs", :force => true do |t|
    t.integer  "job_type_id"
    t.integer  "job_status_id"
    t.integer  "user_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.text     "error_info"
  end

  add_index "jobs", ["job_status_id"], :name => "index_jobs_on_job_status_id"
  add_index "jobs", ["job_type_id"], :name => "index_jobs_on_job_type_id"
  add_index "jobs", ["user_id"], :name => "index_jobs_on_user_id"

  create_table "labs", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "labs_parts", :force => true do |t|
    t.integer  "lab_id"
    t.integer  "part_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "labs_parts", ["lab_id"], :name => "index_labs_parts_on_lab_id"
  add_index "labs_parts", ["part_id"], :name => "index_labs_parts_on_part_id"

  create_table "orders", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.integer  "vendor_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "orders", ["user_id"], :name => "index_orders_on_user_id"
  add_index "orders", ["vendor_id"], :name => "index_orders_on_vendor_id"

  create_table "organisms", :force => true do |t|
    t.string   "name"
    t.string   "fullname"
    t.integer  "code"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "parts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text     "comment"
  end

  create_table "protocols", :force => true do |t|
    t.string   "name"
    t.string   "int_prefix"
    t.string   "int_suffix"
    t.text     "overlap"
    t.integer  "construct_size"
    t.string   "forbid_enzymes"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.string   "ext_prefix"
    t.string   "ext_suffix"
    t.integer  "organism_id"
    t.string   "check_enzymes"
    t.text     "comment"
    t.integer  "lab_id"
  end

  add_index "protocols", ["lab_id"], :name => "index_protocols_on_lab_id"
  add_index "protocols", ["organism_id"], :name => "index_protocols_on_organism_id"

  create_table "sequences", :force => true do |t|
    t.string   "accession"
    t.integer  "organism_id"
    t.integer  "part_id"
    t.text     "seq"
    t.string   "annotation"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "seq_type"
  end

  add_index "sequences", ["organism_id"], :name => "index_sequences_on_organism_id"
  add_index "sequences", ["part_id"], :name => "index_sequences_on_part_id"

  create_table "users", :force => true do |t|
    t.string   "uid"
    t.string   "fullname"
    t.string   "email"
    t.string   "provider"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "group_id"
    t.integer  "lab_id"
  end

  add_index "users", ["lab_id"], :name => "index_users_on_lab_id"

  create_table "vendors", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

end
