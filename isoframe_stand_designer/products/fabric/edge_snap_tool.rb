# frozen_string_literal: true
# Drag Fabric wall top → height snaps; drag side → width snaps every 250 mm.
# Under the hood width = 900 starter + 1000/750/500/250 extensions. No flex.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        class EdgeSnapTool
          EDGE_TOL_MM = 80.0

          def activate
            @ip = Sketchup::InputPoint.new
            @wall = selected_fabric_wall
            @mode = nil
            @dragging = false
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
            @dragging = false
            @mode = nil
            view.invalidate
          end

          def onMouseMove(_flags, x, y, view)
            @ip.pick(view, x, y)
            if @dragging && @wall && @wall.valid? && @mode
              apply_drag!(@ip.position) if @ip.valid?
            end
            view.invalidate
          end

          def onLButtonDown(_flags, x, y, view)
            @ip.pick(view, x, y)
            return unless @ip.valid?
            @wall = pick_fabric_wall(view, x, y) || selected_fabric_wall
            unless @wall && @wall.valid?
              UI.messagebox('Fabric Edge Snap: select or click a Fabric wall first.')
              return
            end
            @mode = infer_mode(@wall, @ip.position)
            @dragging = true
            update_status
            view.invalidate
          end

          def onLButtonUp(_flags, x, y, view)
            if @dragging && @wall && @wall.valid?
              @ip.pick(view, x, y)
              apply_drag!(@ip.position) if @ip.valid?
              finalize_drag!
            end
            @dragging = false
            @mode = nil
            update_status
            view.invalidate
          end

          def draw(view)
            return unless @wall && @wall.valid?
            bb = @wall.bounds
            view.drawing_color = 'orange'
            view.line_width = 2
            pts = [
              Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
              Geom::Point3d.new(bb.max.x, bb.min.y, bb.max.z),
              Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z),
              Geom::Point3d.new(bb.min.x, bb.max.y, bb.max.z)
            ]
            view.draw(GL_LINE_LOOP, pts)
            return unless @ip && @ip.valid?
            view.draw_points([@ip.position], 8, 2, 'red')
          end

          def getExtents
            bb = Geom::BoundingBox.new
            bb.add(@wall.bounds) if @wall && @wall.valid?
            bb.add(@ip.position) if @ip && @ip.valid?
            bb
          end

          private

          def update_status
            if @dragging && @mode
              Sketchup.status_text =
                "Fabric Edge Snap: dragging #{@mode}. Release to lock snap."
            else
              Sketchup.status_text =
                'Fabric Edge Snap: click top edge = height, side edge = width (250 mm).'
            end
          end

          def selected_fabric_wall
            model = Sketchup.active_model
            return nil unless model
            model.selection.grep(Sketchup::ComponentInstance).find { |e| fabric_wall?(e) }
          end

          def fabric_wall?(ent)
            return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
            Attributes.get(ent, ::ISOframe::StandDesigner::Constants::KEY_TYPE).to_s ==
              ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL
          end

          def pick_fabric_wall(view, x, y)
            ph = view.pick_helper
            ph.do_pick(x, y)
            best = nil
            ph.count.times do |i|
              path = ph.path_at(i)
              next unless path
              path.reverse_each do |e|
                if fabric_wall?(e)
                  best = e
                  break
                end
              end
              break if best
            end
            best
          rescue StandardError
            nil
          end

          def infer_mode(wall, world_pt)
            bb = wall.bounds
            local = world_pt.transform(wall.transformation.inverse)
            width = Fabric::Geometry.wall_local_width_mm(wall).mm
            tip = Fabric::Geometry.post_tip_mm(Fabric::Geometry.wall_height_key(wall)).mm
            tol = EDGE_TOL_MM.mm
            return :height if (local.z - tip).abs <= tol || (world_pt.z - bb.max.z).abs <= tol
            return :width if (local.x - width).abs <= tol || local.x.abs <= tol
            (local.z > tip * 0.6) ? :height : :width
          end

          def apply_drag!(world_pt)
            return unless @wall && @wall.valid?
            local = world_pt.transform(@wall.transformation.inverse)
            if @mode == :height
              tip_guess = local.z / 1.mm
              g_h = tip_guess - Fabric::Constants::GRAPHIC_Z_BOT_MM +
                    Fabric::Constants::GRAPHIC_TOP_ABOVE_POST_MM
              @preview_height = Fabric::Geometry.snap_height_key(g_h)
              Sketchup.vcb_label = 'Height'
              Sketchup.vcb_value = @preview_height
              Sketchup.status_text =
                "Fabric height → #{@preview_height} " \
                "(#{Fabric::Constants::HEIGHTS_MM[@preview_height].to_i} mm)"
            else
              w = Fabric::Geometry.snap_width_mm(local.x / 1.mm)
              @preview_width = w
              Sketchup.vcb_label = 'Width'
              Sketchup.vcb_value = "#{w.to_i} mm"
              segs = Fabric::Geometry.decompose_width_mm(w)
              Sketchup.status_text =
                "Fabric width → #{w.to_i} mm (#{segs.map(&:to_i).join('+')})"
            end
          end

          def finalize_drag!
            return unless @wall && @wall.valid?
            model = @wall.model
            width = @preview_width || Fabric::Geometry.wall_local_width_mm(@wall)
            height = @preview_height || Fabric::Geometry.wall_height_key(@wall)
            width = Fabric::Geometry.snap_width_mm(width)
            height = height.to_s
            height = Fabric::Constants::DEFAULT_HEIGHT unless Fabric::Constants::HEIGHTS_MM.key?(height)

            model.start_operation('Fabric Edge Snap', true)
            begin
              @wall.make_unique if @wall.respond_to?(:make_unique)
              Fabric::Geometry.rebuild!(@wall.definition, width, height)
              Attributes.set(@wall, ::ISOframe::StandDesigner::Constants::KEY_HEIGHT, height)
              Attributes.set(
                @wall,
                ::ISOframe::StandDesigner::Constants::KEY_FABRIC_WIDTH_MM,
                width.to_f
              )
              Attributes.set(
                @wall,
                ::ISOframe::StandDesigner::Constants::KEY_RANGE,
                ::ISOframe::StandDesigner::Constants::RANGE_FABRIC
              )
              Attributes.set(
                @wall,
                ::ISOframe::StandDesigner::Constants::KEY_TYPE,
                ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL
              )
              Constraints.mark_floor_slide!(@wall)
              Constraints.snap_floor_sitting_to_floor!(@wall)
              model.selection.clear
              model.selection.add(@wall)
              segs = Fabric::Geometry.decompose_width_mm(width)
              Sketchup.status_text =
                "Fabric snapped: #{height} × #{width.to_i} mm [#{segs.map(&:to_i).join('+')}]"
              model.commit_operation
            rescue StandardError => e
              model.abort_operation
              UI.messagebox("Fabric Edge Snap failed:\n#{e.message}")
            end
          end
        end
      end
    end
  end
end
