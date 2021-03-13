require "./SPO_pattern_class.rb"


engine = Engine.new()

first_test = engine.extract_patterns("https://rdf.metanetx.org/sparql")
#first_test = engine.extract_patterns("http://sparql.uniprot.org/sparql")

shacl_test = engine.shacl_generator(first_test, "output_test3.ttl")

# print first_test

# puts puts

# first_test["http://swisslipids.org/rdf#HasSourceComponent"].each do |pattern|
#     puts "Subject: #{pattern.SPO_Subject}, Predicate: #{pattern.SPO_Predicate}, Object: #{pattern.SPO_Object}"
# end
