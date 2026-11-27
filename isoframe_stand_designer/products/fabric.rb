# frozen_string_literal: true
# Fabric product shell (v0.1.81). Empty — do not call Wave APIs from here.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module_function

        PRODUCT_ID = 'fabric'

        def ready?
          false
        end

        def coming_soon_message
          Products.coming_soon_message(PRODUCT_ID)
        end
      end
    end
  end
end
