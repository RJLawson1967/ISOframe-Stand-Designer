# frozen_string_literal: true
# Click-to-place freestanding counter on the floorspace (Z = floor top).
# Not attached to Wave modules. v0.1.78: Move is floor-slide only (Z locked;
# feet stay on floorspace top — see Constraints.snap_freestanding_to_floor!).

module ISOframe
  module StandDesigner
    module Tools
      class PlaceCounterTool
        def initialize(kind = 'oval')
          @kind = kind.to_s
          @entry = Counters::REGISTRY[@kind]
          raise ArgumentError, "Unknown counter kind: #{kind}" unless @entry
        end

        def activate
          @ip = Sketchup::InputPoint.new
          update_status
        end

        def deactivate(view)
          view.invalidate
        end

        def resume(view)
          update_status
          view.invalidate
        end

        def onCancel(_reason, view)
          view.invalidate
        end

        def onMouseMove(_flags, x, y, view)
          @ip.pick(view, x, y)
          view.tooltip = @ip.tooltip if @ip.valid?
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          @ip.pick(view, x, y)
          return unless @ip.valid?
          place_at(@ip.position)
          view.invalidate
        end

        def draw(view)
          return unless @ip && @ip.valid?
          view.draw_points([@ip.position], 8, 2, 'blue')
        end

        def getExtents
          bb = Geom::BoundingBox.new
          bb.add(@ip.position) if @ip && @ip.valid?
          bb
        end

        private

        def update_status
          label = @entry[:label]
          Sketchup.status_text =
            "ISOframe: click to place #{label} on the floor. Esc to cancel."
        end

        def place_at(point)
          return unless License.require_active!
          return unless Floorspace.require_defined!
          model = Sketchup.active_model
          model.start_operation("Place #{@entry[:label]}", true)
          begin
            defn = Counters.definition_for!(model, @kind)
            origin = Geom::Point3d.new(point.x, point.y, Floorspace.module_base_z(model))
            tr = Geom::Transformation.new(origin)
            inst = model.active_entities.add_instance(defn, tr)
            inst.name = @entry[:instance_name]
            Attributes.set(inst, Constants::KEY_TYPE, Constants::TYPE_COUNTER)
            Attributes.set(inst, Constants::KEY_COUNTER_KIND, @kind)
            Constraints.ensure_freestanding_on_floor!(inst)
            model.selection.clear
            model.selection.add(inst)
            Sketchup.status_text =
              "Placed #{@entry[:label]} — slides on the floor (Z locked); " \
              'select it and Add Artwork to wrap.'
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Place #{@entry[:label]} failed:\n#{e.message}")
          end
        end
      end
    end
  end
end
