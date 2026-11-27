# frozen_string_literal: true
# Product-line firewall (v0.1.81).
#
# Each product lives in ISOframe::StandDesigner::Products::<Name> with no shared
# mutable product state. Wave keeps current behaviour via a thin facade that
# delegates to existing Wave modules. Fabric/Lumen/Ripple/ISObar/Express are
# empty shells until filled later — edits there must not change Wave.

module ISOframe
  module StandDesigner
    module Products
      # Locked tab order (panel + menu).
      IDS = %w[wave fabric lumen ripple isobar express].freeze

      LABELS = {
        'wave' => 'Wave',
        'fabric' => 'Fabric',
        'lumen' => 'Lumen',
        'ripple' => 'Ripple',
        'isobar' => 'ISObar',
        'express' => 'Express'
      }.freeze

      module_function

      def label_for(id)
        LABELS[id.to_s] || id.to_s
      end

      def each_id
        IDS.each { |id| yield id, label_for(id) }
      end

      def shell?(id)
        id.to_s != 'wave'
      end

      def coming_soon_message(id)
        "#{label_for(id)} — coming soon"
      end
    end
  end
end
