=begin
Questions:
- If I understand correctly, there should be a SHACL shape     
=end

require "sparql/client"
require "digest"

class SPO
    attr_accessor :SPO_Subject
    attr_accessor :SPO_Predicate
    attr_accessor :SPO_Object

    def initialize(params = {})
        @SPO_Subject = params.fetch(:SPO_Subject, "")
        @SPO_Predicate = params.fetch(:SPO_Predicate, "")
        @SPO_Object = params.fetch(:SPO_Object, "")
    end
end

class Engine
    attr_accessor :hashed_patterns
    attr_accessor :patterns

    def initialize(params = {})
        @hashed_patterns = []
        @patterns = []
    end
    def in_database?(s,p,o)
        pattern_digest = Digest::SHA2.hexdigest s.to_s+p.to_s+o.to_s
        if hashed_patterns.include? pattern_digest
            return true
        else
            hashed_patterns << pattern_digest
            return false
        end
    end
        
    def add_triple_pattern(type, s,p,o)
        if @patterns.include? type
            @patterns[type] << SPO.new(
                :SPO_Subject => s,
                :SPO_Predicate => p,
                :SPO_Object => o
            )
        else
            @patterns[type] = [SPO.new(
                :SPO_Subject => s,
                :SPO_Predicate => p,
                :SPO_Object => o
            )]
        end
    end
    
    def query_endpoint(endpoint_URL, mode = "exploratory", type = "")
        abort "must provide a type in any mode other than exploratory" if mode != "exploratory" and type.to_s.empty?
        sparql = SPARQL::Client.new(endpoint_URL)
        if mode == "exploratory"
            #This first query asks for the types of objects inside the triplestore
            query = <<END
SELECT DISTINCT ?type
WHERE {
    ?subject a ?type .
}
END
            result = sparql.query(query)
        
        elsif mode == "fixed_subject"
            #Recordatorio para poner el OPTIONAL en el ?object_type
            query = <<END
        
            SELECT DISTINCT ?predicate ?object_type
            WHERE {
                ?subject a <#{type}>.
                ?subject ?predicate ?object . 
                ?object a ?object_type.
            } limit 10
END
            $stderr.puts "query is:\n#{query}\n\n"
            result = sparql.query(query)

        elsif mode == "fixed_object"
            query = <<END
        
            SELECT DISTINCT ?predicate ?subject_type 
            WHERE {
                ?object a <#{type}>.
                ?subject ?predicate ?object . 
                ?subject a ?subject_type.
            } limit 10
END
            $stderr.puts "query is:\n#{query}\n\n"
            result = sparql.query(query)
        end
        
        return result        
    end

    def extract_patterns(endpoint_URL)
        @patterns = Hash.new
        
        types_array = Array.new

        exploration_results = query_endpoint(endpoint_URL, "exploratory")
        $stderr.puts exploration_results.length.to_s + " types found"
        #The types are stored in an array so that they can be later explored individually in order
        exploration_results.each do |solution|
            next if solution[:type].to_s =~ /openlink/
            next if solution[:type].to_s =~ /w3\.org/
            
            if types_array.include? solution[:type].to_s  # necessary because the ruby object wont be the same object, even if the content is the same
                next
            else
                types_array << solution[:type].to_s
            end
        end
        
        #puts types_array
        
        types_array.each do |type|
                    
            #This query asks for the types of objects and the predicates that interact with each of the types
            fsubject_results = query_endpoint(endpoint_URL, "fixed_subject", type)
            fsubject_results.each do |solution|
                next if solution[:object_type] =~ /rdf-schema/
                next if solution[:object_type] =~ /owl\#Ontology/
                
                #Recordatorio para poner la comprobacion de si solution tiene un :object o un :object_type, y crear el objeto con lo que tengan
                # do a quick lookup to see if we already know this pattern
                next if in_database?(type,solution[:predicate],solution[:object_type]) # this will add it to teh database if it is not known
                add_triple_pattern(type, type, solution[:predicate], solution[:object_type])
                
            end
            fobject_results = query_endpoint(endpoint_URL, "fixed_object", type)
            fobject_results.each do |solution|
                # do a quick lookup to see if we already know this pattern
                next if in_database?(solution[:subject_type],solution[:predicate],type) # this will add it to teh database if it is not known
                #falta comprobacion de que no tenga ya ese pattern
                add_triple_pattern(type, solution[:subject_type],solution[:predicate], type)
            end
        end
        return @patterns          
    end

    def shacl_generator(patterns_hash, output_file)
        File.open(output_file, "w") {|file|
            patterns_hash.each do |key, value|
                value.each do |pattern|
                    if subject == pattern.SPO_Subject
                        shape = "\tsh:property [\n\t\tsh:path <#{pattern.SPO_Predicate}> ;\n\t\tsh:class <#{pattern.SPO_Object}> ;\n\t] ;\n"
                    else 
                        shape = "<#{pattern.SPO_Subject}_SHAPE>\n\ta sh:NodeShape ;\n\tsh:targetClass <#{pattern.SPO_Subject}> ;\n\tsh:property [\n\t\tsh:path <#{pattern.SPO_Predicate}> ;\n\t\tsh:class <#{pattern.SPO_Object}> ;\n\t] ;\n"
                        subject = pattern.SPO_Subject
                    end
                    file.write shape
                end
            end
        }
    end    
end