require "io/console"

class Pry
  module DefaultCommands
    FindMethod = Pry::CommandSet.new do
        
        
        create_command "find-method" do   
            
            group "Context"
            
            description "Recursively search for a method within a Class/Module or the current namespace. find-method [-n | -c] METHOD [NAMESPACE]"
            
            def options(opti)
                opti.on :n, :name, "Search for a method by name"
                opti.on :c, :content, "Search for a method based on content in Regex form"
            end
            
            def process
                return if args.size < 1
                pattern = ::Regexp.new args[0]
                if args[1]
                    klass = target.eval(args[1])
                    if !klass.is_a?(Module)
                        klass = klass.class
                    end
                else    
                    to_put = target_self_eval(pattern, opts)
                    if to_put.flatten == []
                        puts "\e[31;1mNo Methods Found\e[0m"
                    else
                        puts "\e[32;1;4mMethods Found\e[0m"
                        puts to_put
                    end
                    return
                end
                if opts.name?
                    to_put = name_search(pattern, klass)
                elsif opts.content?
                    to_put = content_search(pattern, klass)
                else
                    to_put = name_search(pattern, klass)
                end
                1
                if to_put.flatten == []
                    puts "\e[31;1mNo Methods Found\e[0m"
                else
                    puts "\e[1;4;32mMethods Found\e[0m"
                    puts to_put
                end

            end
            
            private

            def puts(item)
                output.puts item
            end
            
            def target_self_eval(pattern, opts)
                obj = target_self
                if opts.name?
                    #return (Pry::Method.all_from_obj(obj).select {|x| x.name =~ pattern}).map {|x| "(#{obj.to_s})##{x.name}"}
                    header = "(#{obj}):  "
                    ret = [header + "\n"]
                    Pry::Method.all_from_obj(obj).each do |x|
                        if x.name =~ pattern
                            add = (' ' * header.length) + x.name
                            begin
                                add += "\x1A\x1" if x.alias?
                            rescue EOFError
                            end
                            #add += "\t\t(Alias)" if x.alias?
                            ret << add
                        end
                    end
                    max = ret.map(&:length).max
                    ret.map! do |x|
                        str = " " * ((max - x.length) + 2)
                        str += "\e[33;1m(Alias)\e[0m"
                        x.sub("\x1A\x1", str)
                    end
                    return ret
                elsif opts.content?
                    ret = []
                    Pry::Method.all_from_obj(obj).each do |x|
                        begin
                            if x.source =~ pattern
                                header = "(#{obj.to_s})##{x.name}:  "
                                ret << header + colorize_code((x.source.split(/\n/).select {|y| y =~ pattern}).join("\n\n#{' ' * header.length}" ))
                            end
                        rescue Exception
                            next
                        end
                    end
                    return ret
                else
                    return (Pry::Method.all_from_obj(obj).select {|x| x.name =~ pattern}).map {|x| "(#{obj.to_s})##{x.name}"}
                end  
            end

            def content_search(pattern, klass, current=[])
                return unless(klass.is_a? Module)
                return if current.include? klass
                current << klass
                meths = []
                (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each do |meth|
                begin
                    if meth.source =~ pattern && !meth.alias?
                        header = "#{klass}##{meth.name}:  "
                        meths <<  header + colorize_code((meth.source.split(/\n/).select {|x| x =~ pattern }).join("\n#{' ' * header.length}"))
                    end
                rescue Exception
                    next
                rescue Pry::CommandError
                    next
                end
                end
                klass.constants.each do |klazz|
                    meths += ((res = content_search(pattern, klass.const_get(klazz), current)) ? res : [])
                end
                return meths.uniq.flatten
            end
                    
            def name_search(regex, klass, current=[])
                return unless(klass.is_a? Module)
                return if current.include? klass
                current << klass
                header = "\e[1;34;4m#{klass.name}\e[0;24m" + " \e[1m{\e[0m\n\n"
                meths = []
                (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each do |x|
                   if x.name =~ regex
                        meths << "#{' ' * (header.length - 25)}#{x.name}" 
                        #begin
                        #    meths[-1] += "\x1A" if x.alias?
                        #rescue Exception
                        #end
                   end
                    
                end
                #max = meths.map(&:length).max
                #meths.map! do |x|
                #    x.sub("\x1A", ((' ' * ((max - x.length) + 2)) + "\e[33m(Alias)\e[0m"))
                #end
                meths.unshift header
                meths << "\e[1m}\e[0m\n\n"
                klass.constants.each do |x|
                    begin
                        meths << ((res = name_search(regex, klass.const_get(x), current)) ? res : [])
                    rescue Exception
                        next
                    end
                end
                return meths.uniq.flatten
            end 
            
        end
    end
  end
end