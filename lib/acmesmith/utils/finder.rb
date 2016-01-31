module Acmesmith
  module Utils
    module Finder
      def self.find(const, prefix, name)
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

          nil
        end
      end
    end
  end
end
