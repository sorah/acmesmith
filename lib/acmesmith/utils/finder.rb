module Acmesmith
  module Utils
    module Finder
      class NotFound < StandardError; end

      def self.find(const, prefix, name, error: true)
        retried = false
        constant_name = name.to_s.gsub(/\A.|_./) { |s| s[-1].upcase }

        begin
          const.const_get constant_name, false
        rescue NameError
          unless retried
            begin
              require "#{prefix}/#{name}"
            rescue LoadError
            end

            retried = true
            retry
          end

          if error
            raise NotFound, "Couldn't find #{name.inspect} for #{const}"
          else
            nil
          end
        end
      end
    end
  end
end
