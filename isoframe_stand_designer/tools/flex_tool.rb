# frozen_string_literal: true
# Flex tool: choose fixed hinge post (Fix Left / Fix Right), then bend.
# Physical model (v0.1.29):
#   - Fixed post = immovable (world position + orientation from mouse-down).
#   - Flexing bay = arm with locked Wave bend (face_path / flats / free yaw).
#   - Free-side modules = stick: T_new = F_new * F_old.inverse * T_old.
# Fix Right pins world-right via Δθ about that pin only (no flip/bake, no
# origin reset to 0,0,0). Bend math unchanged vs v0.1.25.

module ISOframe
  module StandDesigner
    module Tools
      class FlexTool
        def activate
          @inst = selected_flexible
          unless @inst
            UI.messagebox('Select a Wave flexible starter or extension, then Flex.')
            Sketchup.active_model.select_tool(nil)
            return
          end
          if defined?(Tables) && Tables.table_on?(@inst)
            UI.messagebox(
              'This module has a table add-on. Remove the table first (Keyboard Table ' \
              'again), then Flex. Tables are straight-only.'
            )
            Sketchup.active_model.select_tool(nil)
            return
          end
          @hinge_side = Constants::HINGE_LEFT
          @base_angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f
          @drag_angle = @base_angle
          @pivoting = false
          @op_open = false
          @chain = []
          @chain_tr0 = {}
          @flex0_tr = nil
          @pin_point = nil
          @pin_yaw = nil
          @hinge0_pt = nil
          @free0_pt = nil
          @free0_frame_a = nil
          update_status
        end

        def deactivate(view)
          abort_open_operation
          view.invalidate
        end

        def onCancel(_reason, view)
          abort_open_operation
          @pivoting = false
          clear_session_snapshots!
          @drag_angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f if @inst && @inst.valid?
          update_status
          view.invalidate
        end

        def onKeyDown(key, _repeat, _flags, view)
          return if @pivoting
          # SketchUp key codes: L=76, R=82 (also accept lowercase).
          case key
          when 76, 108
            set_hinge_side!(Constants::HINGE_LEFT)
            update_status
            view.invalidate
          when 82, 114
            set_hinge_side!(Constants::HINGE_RIGHT)
            update_status
            view.invalidate
          end
        rescue StandardError
          nil
        end

        def onMouseMove(_flags, x, y, view)
          return unless @pivoting && @inst && @inst.valid? && @op_open
          dx = x - @down_x
          raw = @base_angle + dx * 0.5
          @drag_angle = quantize_and_snap(raw)
          apply_session_flex!(@drag_angle)
          update_status
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          return unless @inst && @inst.valid?
          abort_open_operation

          # Click nearer a post to pick hinge (before drag).
          pick_hinge_from_click!(view, x, y) unless @pivoting

          @pivoting = true
          @down_x = x
          @base_angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f
          @drag_angle = @base_angle
          snapshot_session!
          Sketchup.active_model.start_operation('Flex Wave Module', true)
          @op_open = true
          apply_session_flex!(@drag_angle)
          update_status
          view.invalidate
        end

        def onLButtonUp(_flags, _x, _y, view)
          return unless @pivoting
          @pivoting = false
          if @op_open && @inst && @inst.valid?
            apply_session_flex!(@drag_angle)
            Sketchup.active_model.commit_operation
            @op_open = false
            @base_angle = @drag_angle
            Sketchup.status_text =
              "Flex angle: #{@drag_angle.round}° — hinge #{hinge_label}" \
              "#{@chain.empty? ? '' : " (moved #{@chain.size} linked)"}"
          end
          clear_session_snapshots!
          update_status
          view.invalidate
        end

        def onUserText(text, view)
          return unless @inst && @inst.valid?
          begin
            val = Float(text)
          rescue ArgumentError
            UI.beep
            return
          end
          abort_open_operation
          @pivoting = false
          angle = quantize_and_snap(val)
          @base_angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f
          @drag_angle = angle
          snapshot_session!
          model = Sketchup.active_model
          model.start_operation('Flex Wave Module', true)
          begin
            apply_session_flex!(angle)
            model.commit_operation
            @base_angle = angle
            @drag_angle = angle
            Sketchup.status_text =
              "Flex angle: #{angle.round}° — hinge #{hinge_label}" \
              "#{@chain.empty? ? '' : " (moved #{@chain.size} linked)"}"
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Flex failed: #{e.message}")
          ensure
            clear_session_snapshots!
            @op_open = false
          end
          update_status
          view.invalidate
        end

        def draw(view)
          return unless @inst && @inst.valid?
          posts = Geometry.semantic_posts(@inst, @drag_angle || 0.0, @hinge_side)
          hinge = posts[:hinge_pt]
          free = posts[:free_pt]
          view.draw_points([hinge], 12, 2, 'orange')
          view.draw_points([free], 10, 2, 'cyan')
          view.drawing_color = 'orange'
          view.draw_text(
            view.screen_coords(hinge),
            " HINGE #{hinge_label}  #{@drag_angle.round}°",
            size: 12,
            bold: true,
            color: 'orange'
          )
          view.drawing_color = 'cyan'
          view.draw_text(
            view.screen_coords(free),
            ' FREE',
            size: 11,
            bold: true,
            color: 'cyan'
          )
        rescue StandardError
          nil
        end

        def getExtents
          bb = Geom::BoundingBox.new
          if @inst && @inst.valid?
            posts = Geometry.semantic_posts(@inst, @drag_angle || 0.0, @hinge_side)
            bb.add(posts[:hinge_pt])
            bb.add(posts[:free_pt])
            @chain.each do |mod|
              next unless mod && mod.valid?
              bb.add(mod.bounds) rescue nil
            end
          end
          bb
        end

        private

        def selected_flexible
          Sketchup.active_model.selection.grep(Sketchup::ComponentInstance).find do |inst|
            type = Attributes.get(inst, Constants::KEY_TYPE)
            next false unless type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
            Attributes.get(inst, Constants::KEY_RANGE) == Constants::RANGE_WAVE
          end
        end

        def set_hinge_side!(side)
          s = side.to_s
          @hinge_side = (s == Constants::HINGE_RIGHT) ? Constants::HINGE_RIGHT : Constants::HINGE_LEFT
        end

        def hinge_label
          @hinge_side == Constants::HINGE_RIGHT ? 'RIGHT' : 'LEFT'
        end

        def pick_hinge_from_click!(view, x, y)
          return unless @inst && @inst.valid?
          angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f
          left = Geometry.hinge_center_local.transform(@inst.transformation)
          right = Geometry.end_post_center_local(angle).transform(@inst.transformation)
          sl = view.screen_coords(left)
          sr = view.screen_coords(right)
          dl = Math.hypot(sl.x - x, sl.y - y)
          dr = Math.hypot(sr.x - x, sr.y - y)
          # Only switch when clearly nearer one post (avoid noise at mid-bay).
          if dl + 12 < dr
            set_hinge_side!(Constants::HINGE_LEFT)
          elsif dr + 12 < dl
            set_hinge_side!(Constants::HINGE_RIGHT)
          end
        rescue StandardError
          nil
        end

        def snapshot_session!
          return unless @inst && @inst.valid?
          # Immutable copies — live Transformation refs must not be reused across
          # drag steps (compounding caused free-side over-rotation / kink).
          @flex0_tr = Geometry.transformation_copy(@inst.transformation)
          @base_angle = Attributes.get(@inst, Constants::KEY_FLEX, 0.0).to_f
          posts0 = Geometry.semantic_posts(@inst, @base_angle, @hinge_side)
          @hinge0_pt = Geom::Point3d.new(posts0[:hinge_pt].x, posts0[:hinge_pt].y, 0)
          @pin_point = Geom::Point3d.new(posts0[:hinge_pt].x, posts0[:hinge_pt].y, 0)
          @pin_yaw = posts0[:hinge_yaw] # frozen scalar; Fix Right uses pin_yaw − θ
          @free0_pt = Geom::Point3d.new(posts0[:free_pt].x, posts0[:free_pt].y, 0)
          @free0_frame_a = Geometry.transformation_copy(
            Geometry.semantic_free_frame(@inst, @base_angle, @hinge_side)
          ).to_a
          @chain = WallGraph.free_side_modules(@inst, @hinge_side)
          @chain_tr0 = {}
          @chain.each do |mod|
            next unless mod && mod.valid?
            @chain_tr0[mod.entityID] = Geometry.transformation_copy(mod.transformation).to_a
          end
        end

        def clear_session_snapshots!
          @chain = []
          @chain_tr0 = {}
          @flex0_tr = nil
          @pin_point = nil
          @pin_yaw = nil
          @hinge0_pt = nil
          @free0_pt = nil
          @free0_frame_a = nil
        end

        def apply_session_flex!(angle)
          return unless @inst && @inst.valid? && @flex0_tr
          # Always restore pre-flex instance transform first so Fix Right pin is
          # absolute vs mouse-down (never Identity / world origin).
          @inst.transformation = Geometry.transformation_copy(@flex0_tr)
          if @hinge_side == Constants::HINGE_RIGHT
            return if @pin_point.nil? || @pin_yaw.nil?
            Geometry.apply_flex_with_hinge!(
              @inst, angle,
              hinge_side: Constants::HINGE_RIGHT,
              pin_point: @pin_point,
              pin_yaw_deg: @pin_yaw
            )
          else
            Geometry.apply_flex_with_hinge!(
              @inst, angle,
              hinge_side: Constants::HINGE_LEFT
            )
          end

          # Stick = rigid relative to free post. One Δ from snapshot frames only
          # (no compounding live transforms; no atan2 rebuild that flips 180°).
          return unless @free0_frame_a
          free0_frame = Geom::Transformation.new(@free0_frame_a)
          free1_frame = Geometry.semantic_free_frame(@inst, angle, @hinge_side)
          return unless free1_frame

          @chain.each do |mod|
            next unless mod && mod.valid?
            arr = @chain_tr0[mod.entityID]
            next unless arr
            tr0 = Geom::Transformation.new(arr)
            # T_new = free_new * free_old.inverse * T_old
            rel = free0_frame.inverse * tr0
            mod.transformation = free1_frame * rel
            # Keep floor lock: origin Z = floor top (or ground if no floorspace).
            Constraints.ensure_module_on_floor!(mod)
          end
          Constraints.ensure_module_on_floor!(@inst) if @inst && @inst.valid?

          assert_hinge_frozen!(angle)
        end

        # Numeric guard each drag: hinge world XY + yaw must match mouse-down snapshot.
        def assert_hinge_frozen!(angle)
          return if @pin_point.nil? || @pin_yaw.nil?
          posts = Geometry.semantic_posts(@inst, angle, @hinge_side)
          dx = posts[:hinge_pt].x - @pin_point.x
          dy = posts[:hinge_pt].y - @pin_point.y
          pos_err_mm = Math.sqrt(dx * dx + dy * dy) / 1.mm
          yaw_err = (posts[:hinge_yaw].to_f - @pin_yaw.to_f).abs
          yaw_err = [yaw_err, 360.0 - yaw_err].min
          @hinge_assert_ok = (pos_err_mm < 0.05 && yaw_err < 0.05)
          unless @hinge_assert_ok
            Sketchup.status_text =
              "ISOframe hinge drift! pos=#{format('%.3f', pos_err_mm)} mm " \
              "yaw=#{format('%.3f', yaw_err)}° — report to support"
          end
        rescue StandardError
          @hinge_assert_ok = false
        end

        def quantize_and_snap(degrees)
          a = [[degrees.to_f, Constants::FLEX_MIN_DEG].max, Constants::FLEX_MAX_DEG].min
          a = a.round(0)
          Constants::FLEX_SNAP_DEG.each do |snap|
            return snap.to_f if (a - snap).abs <= Constants::FLEX_SNAP_TOLERANCE_DEG
          end
          a.to_f
        end

        def abort_open_operation
          return unless @op_open
          Sketchup.active_model.abort_operation
          @op_open = false
        rescue StandardError
          @op_open = false
        end

        def update_status
          snapped = Constants::FLEX_SNAP_DEG.include?(@drag_angle.to_i) ? ' [snap]' : ''
          chain_n = (@chain && !@chain.empty?) ? " | chain #{@chain.size}" : ''
          Sketchup.status_text =
            "ISOframe Flex: hinge #{hinge_label} (L/R or click near post). " \
            "Drag or type ° (−180…180). Current #{@drag_angle.round}°#{snapped}#{chain_n}"
          Sketchup.vcb_label = "Angle [#{hinge_label[0]}]"
          Sketchup.vcb_value = @drag_angle.round.to_s
        end
      end
    end
  end
end
