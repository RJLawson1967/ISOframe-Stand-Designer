# frozen_string_literal: true
# Placeholder Wave geometry (not SolidWorks).
#
# X = along wall when straight; +Y = front face; Z = up (0 .. module height).
#
# Flex (plan):
#   - Hinge post fixed (yaw 0). Free post swings + yaws by flex_angle so its
#     front face stays aligned with the graphic end flat.
#   - Graphic: fixed ~800 mm on the FRONT face — flat 18.5 mm at BOTH posts,
#     circular-arc middle only. Same graphic size for all curves.
#   - Flexi-link: separate beam at BOTTOM, BEHIND the graphic. Back-offset path
#     is shorter on external (convex-front) bends, longer on internal curves.

module ISOframe
  module StandDesigner
    module Geometry
      module_function

      ARC_SEGMENTS = 24
      GEOM_VERSION = 30 # v0.1.49: graphic panel thickness 6 → 3 mm
      KEY_GEOM_VERSION = 'geom_version'
      # Mid aluminium grey — same family as base supports (colour only).
      POST_COLOR = [168, 172, 176].freeze
      BASE_COLOR = [168, 172, 176].freeze
      GROUP_POST_A = 'PostA'
      GROUP_POST_B = 'PostB'
      GROUP_POST_NEW = 'PostNew'
      GROUP_BEAM = 'FlexiBeam'
      GROUP_GRAPHIC = 'GraphicHint'
      GROUP_BASE = 'BaseSupport'
      DEFN_FOOT = 'ISOframe Wave Foot v39'
      OBJ_FOOT = 'wave_foot.obj'
      # Graphic slab depth + tiny lift off the post front face (avoids z-fight show-through).
      GRAPHIC_THICKNESS_MM = 3.0
      GRAPHIC_FRONT_CLEARANCE_MM = 1.0
      # HEIGHTS_MM = overall graphic panel height (Mini/Midi/Maxi). Graphic spans
      # [GRAPHIC_Z_BOT_MM, GRAPHIC_Z_BOT_MM + HEIGHTS_MM]. Post tip is 5 mm below
      # graphic top (graphic protrudes 5 mm above the post).
      GRAPHIC_TOP_ABOVE_POST_MM = 5.0
      # Flexi-link underside clearance above floor (mm). Section size in Constants.
      BEAM_Z_BOT_MM = 100.0
      # Shift beam solid toward graphic (+left-normal) without changing back-offset path length.
      # Front of beam must sit on post front / graphic rear (= POST_MM from back-face path).
      # shift = POST_MM − BEAM_DEPTH/2 → 37 − 12.5 = 24.5 when depth is 25 mm.
      BEAM_TOWARD_GRAPHIC_MM = Constants::POST_MM - (Constants::BEAM_DEPTH_MM / 2.0)
      # Wave foot from Wave_foot.STEP (mm). Plan X = width, Y = front/back.
      # v0.1.39: force 10 mm thick (Richard measures; real plate). Post sits on foot top.
      # Length axis = local +Y (perp to wall / flexi-link); yaws with the post.
      # Detailed mesh: models/wave_foot.obj (Z baked to 10 mm). FOOT_OUTLINE_MM = fallback.
      FOOT_THICKNESS_MM = 10.0
      # Graphic bottom clears the foot plate (same as foot thickness).
      GRAPHIC_Z_BOT_MM = FOOT_THICKNESS_MM
      FOOT_OUTLINE_MM = [
        [0.0, 199.9],
        [5.0, 196.9],
        [10.4, 187.0],
        [19.7, 150.0],
        [27.4, 80.0],
        [29.8, 3.6],
        [22.9, -149.2],
        [0.0, -169.9],
        [-22.9, -149.2],
        [-29.8, 3.6],
        [-27.4, 80.0],
        [-19.7, 150.0],
        [-10.4, 187.0],
        [-5.0, 196.9]
      ].freeze
      # Legacy names kept for any older references.
      BASE_LENGTH_MM = 370.0
      BASE_WIDTH_MM = 55.0
      BASE_THICKNESS_MM = FOOT_THICKNESS_MM
      BASE_ELLIPSE_SEGS = 32

      def definition_name(type, height_key)
        "ISOframe Wave #{type.capitalize} #{height_key.capitalize}"
      end

      def definition_for(model, type, height_key)
        height_key = height_key.to_s.downcase
        height_key = Constants::DEFAULT_HEIGHT unless Constants::HEIGHTS_MM.key?(height_key)
        name = definition_name(type, height_key)

        existing = model.definitions[name]
        # Place template must always be straight (flex 0°). If a prior Flex baked a
        # curve into this shared name (make_unique is a no-op on a lone instance),
        # detach those instances first, then rebuild at 0°.
        if existing && !existing.image?
          existing.instances.to_a.each do |inst|
            next unless inst && inst.valid?
            force_unique_definition!(inst, type, height_key)
          end
          if existing.entities.size > 0 &&
             Attributes.get(existing, KEY_GEOM_VERSION, 0).to_i >= GEOM_VERSION
            # Heal any baked curve back to the straight place template.
            rebuild_definition!(existing, type, height_key, 0.0)
            return existing
          end
        end

        defn = existing || model.definitions.add(name)
        rebuild_definition!(defn, type, height_key, 0.0)
        defn
      end

      def rebuild_definition!(defn, type, height_key, flex_angle_deg)
        height_key = height_key.to_s.downcase
        # HEIGHTS_MM = graphic panel height (not post tip).
        graphic_mm = Constants::HEIGHTS_MM[height_key]
        raise ArgumentError, "Unknown height: #{height_key}" unless graphic_mm

        defn.entities.clear! if defn.entities.size > 0
        case type.to_s
        when Constants::TYPE_STARTER
          build_starter!(defn, graphic_mm, flex_angle_deg)
        when Constants::TYPE_EXTENSION
          build_extension!(defn, graphic_mm, flex_angle_deg)
        else
          raise ArgumentError, "Unknown module type: #{type}"
        end

        Attributes.set_many(defn, {
          Constants::KEY_RANGE => Constants::RANGE_WAVE,
          Constants::KEY_TYPE => type.to_s,
          Constants::KEY_HEIGHT => height_key,
          KEY_GEOM_VERSION => GEOM_VERSION
        })
        defn
      end

      def apply_flex_to_instance!(inst, flex_angle_deg)
        return unless inst && inst.valid?

        type = Attributes.get(inst, Constants::KEY_TYPE)
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        angle = flex_angle_deg.to_f

        # Never bake flex into the shared Place template. SketchUp make_unique is a
        # no-op when instances.size == 1, which previously mutated the 0° template
        # (new Starters appeared at 90°; Place used KEY_FLEX while solids disagreed).
        defn = force_unique_definition!(inst, type, height_key)

        rebuild_definition!(defn, type, height_key, angle)
        Attributes.set(inst, Constants::KEY_FLEX, angle)
        Lights.sync!(inst) if defined?(Lights)
        Tables.sync!(inst) if defined?(Tables)
        # Materials only — re-stretch wallpaper UVs after solid rebuild (bend math unchanged).
        Artwork.reapply_after_rebuild!(inst) if defined?(Artwork)
        Constraints.ensure_module_on_floor!(inst) if defined?(Constraints)
        inst
      end

      # Erase Flexi-link (GROUP_BEAM) from a module definition — used when a table
      # add-on is attached. Does not change bend path math.
      def erase_flexi_beam!(defn)
        return unless defn
        defn.entities.to_a.each do |e|
          next unless e.respond_to?(:name)
          next unless e.name.to_s == GROUP_BEAM
          e.erase! if e.valid?
        end
      end

      # HEIGHTS_MM values are overall graphic panel heights (z_top − z_bot).
      # Kept as a function so artwork / callers can pass the HEIGHTS_MM entry directly.
      def graphic_panel_height_mm(graphic_height_mm)
        graphic_height_mm.to_f
      end

      # Post tip Z (mm): graphic top is GRAPHIC_TOP_ABOVE_POST_MM above the tip.
      # z_bot = GRAPHIC_Z_BOT_MM; z_top = z_bot + graphic_height; tip = z_top − 5.
      def post_tip_height_mm(graphic_height_mm)
        GRAPHIC_Z_BOT_MM + graphic_height_mm.to_f - GRAPHIC_TOP_ABOVE_POST_MM
      end

      def graphic_z_bot_mm
        GRAPHIC_Z_BOT_MM
      end

      def graphic_z_top_mm(graphic_height_mm)
        GRAPHIC_Z_BOT_MM + graphic_height_mm.to_f
      end

      # Rebuild with locked left-hinge math. Fix Right then adjusts the instance
      # transform about the frozen world-right pin (Δθ only) so that post's world
      # frame matches the mouse-down snapshot. Does not alter face_path /
      # end_post_center_local / flats / free-post yaw rules. No flip/bake.
      def apply_flex_with_hinge!(inst, flex_angle_deg, hinge_side:, pin_point: nil, pin_yaw_deg: nil)
        return unless inst && inst.valid?
        angle = flex_angle_deg.to_f
        side = hinge_side.to_s
        side = Constants::HINGE_LEFT if side.empty?

        apply_flex_to_instance!(inst, angle)
        if side == Constants::HINGE_RIGHT && pin_point && !pin_yaw_deg.nil?
          pin_world_right_post!(inst, angle, pin_point, pin_yaw_deg)
          # Pin adjusts host world pose after rebuild — keep sibling table glued.
          Tables.reposition_table_for_host!(inst) if defined?(Tables) && Tables.table_on?(inst)
        end
        inst
      end

      # World yaw (degrees) of an instance's local +X axis about Z.
      def transformation_yaw_deg(tr)
        x = tr.xaxis
        Math.atan2(x.y, x.x).radians
      end

      def axes_from_yaw_deg(yaw_deg)
        yaw = yaw_deg.to_f.degrees
        xaxis = Geom::Vector3d.new(Math.cos(yaw), Math.sin(yaw), 0)
        zaxis = Geom::Vector3d.new(0, 0, 1)
        yaxis = zaxis.cross(xaxis)
        xaxis.length = 1
        yaxis.length = 1
        zaxis.length = 1
        [xaxis, yaxis, zaxis]
      end

      def frame_transform(origin, yaw_deg)
        xaxis, yaxis, zaxis = axes_from_yaw_deg(yaw_deg)
        Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
      end

      # Local-left = definition hinge; local-right = free. hinge_side selects which
      # post is fixed in world for this flex session.
      # Right-handed Place only (v0.1.29): free (local-right) world yaw = inst_yaw + θ.
      # Mirrored Place (det −1) was dropped in v0.1.33 — SketchUp can force RH on
      # assigned transforms, which broke Fix Right hinge orientation freeze.
      def semantic_posts(inst, flex_angle_deg, hinge_side)
        tr = inst.transformation
        ang = flex_angle_deg.to_f
        yaw = transformation_yaw_deg(tr)
        left_pt = hinge_center_local.transform(tr)
        right_pt = end_post_center_local(ang).transform(tr)
        left_yaw = yaw
        right_yaw = yaw + ang
        side = hinge_side.to_s
        if side == Constants::HINGE_RIGHT
          {
            hinge_pt: right_pt,
            hinge_yaw: right_yaw,
            free_pt: left_pt,
            free_yaw: left_yaw,
            local_hinge_pt: left_pt,
            local_free_pt: right_pt
          }
        else
          {
            hinge_pt: left_pt,
            hinge_yaw: left_yaw,
            free_pt: right_pt,
            free_yaw: right_yaw,
            local_hinge_pt: left_pt,
            local_free_pt: right_pt
          }
        end
      end

      # Fix Right: after rebuild at `angle`, keep the world-right post fixed in
      # position and orientation. pin_* come from the mouse-down snapshot
      # (frozen scalars — never re-atan2 live axes mid-drag, which can flip 180°).
      # Right-post world yaw = inst_yaw + angle; hold it at pin_yaw ⇒
      # inst_yaw = pin_yaw − angle (Δθ about that pin only). Origin is solved so
      # end_post_center_local(angle) maps to pin_point — never Identity/0,0,0.
      def pin_world_right_post!(inst, angle, pin_point, pin_yaw_deg)
        return unless inst && inst.valid?
        return if pin_point.nil? || pin_yaw_deg.nil?

        ang = angle.to_f
        yaw_inst = pin_yaw_deg.to_f - ang
        xaxis, yaxis, zaxis = axes_from_yaw_deg(yaw_inst)
        free_local = end_post_center_local(ang)
        origin = Geom::Point3d.new(
          pin_point.x - free_local.x * xaxis.x - free_local.y * yaxis.x,
          pin_point.y - free_local.x * xaxis.y - free_local.y * yaxis.y,
          Floorspace.module_base_z(inst.model)
        )
        inst.transformation = Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
        inst
      end

      # Alias kept for any older call sites.
      def pin_local_free_post!(inst, angle, pinned_world_point, pinned_world_yaw_deg)
        pin_world_right_post!(inst, angle, pinned_world_point, pinned_world_yaw_deg)
      end

      # World frame (origin + axes) at the semantic hinge post — for snapshot /
      # numeric checks that hinge stays put while flexing.
      def semantic_hinge_frame(inst, flex_angle_deg, hinge_side)
        posts = semantic_posts(inst, flex_angle_deg, hinge_side)
        frame_transform(posts[:hinge_pt], posts[:hinge_yaw])
      end

      # Rigid map taking old free-post frame → new free-post frame (Z rotation + translate).
      # Prefer chain_rigid_map (Δflex about free post + translate) — same SE(2) result
      # when delta = to_yaw − from_yaw, but avoids reconstructing frames from yaw.
      def free_post_rigid_map(from_pt, from_yaw_deg, to_pt, to_yaw_deg)
        delta = to_yaw_deg.to_f - from_yaw_deg.to_f
        chain_rigid_map(from_pt, to_pt, delta)
      end

      # Unique plan rigid motion: rotate by delta_deg about Z through from_pt, then
      # translate so from_pt lands on to_pt. Orientation change = delta_deg only once
      # (matches free-post yaw change for Fix Left; use −Δflex for Fix Right).
      def chain_rigid_map(from_pt, to_pt, delta_deg)
        from = Geom::Point3d.new(from_pt.x, from_pt.y, 0)
        to = Geom::Point3d.new(to_pt.x, to_pt.y, 0)
        rot = Geom::Transformation.rotation(
          from,
          Geom::Vector3d.new(0, 0, 1),
          delta_deg.to_f.degrees
        )
        xlate = Geom::Transformation.translation(
          Geom::Vector3d.new(to.x - from.x, to.y - from.y, 0)
        )
        xlate * rot
      end

      # World frame at the semantic free post — same axes as Place Extension uses
      # at the open end (outgoing_local_axes), so chain relative pose matches attach.
      def semantic_free_frame(inst, flex_angle_deg, hinge_side)
        atr = inst.transformation
        ang = flex_angle_deg.to_f
        side = hinge_side.to_s
        if side == Constants::HINGE_RIGHT
          x_loc = Geom::Vector3d.new(1, 0, 0)
          y_loc = Geom::Vector3d.new(0, 1, 0)
          z_loc = Geom::Vector3d.new(0, 0, 1)
          origin = hinge_center_local.transform(atr)
        else
          x_loc, y_loc, z_loc = outgoing_local_axes(ang)
          origin = end_post_center_local(ang).transform(atr)
        end
        xaxis = x_loc.transform(atr)
        yaxis = y_loc.transform(atr)
        zaxis = z_loc.transform(atr)
        xaxis.length = 1
        yaxis.length = 1
        zaxis.length = 1
        origin = Geom::Point3d.new(origin.x, origin.y, Floorspace.module_base_z(inst.model))
        Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
      end

      # Copy a transformation to a fresh object (16 floats) so later assigns cannot
      # mutate a stored snapshot — live Transformation refs were compounding the chain.
      def transformation_copy(tr)
        Geom::Transformation.new(tr.to_a)
      end

      def shared_template?(defn, type, height_key)
        defn && defn.name == definition_name(type, height_key)
      end

      # Detach `inst` from the shared Place template before any flex/artwork rebuild.
      # Uses a temporary sibling instance so make_unique always copies, even when
      # this was the only instance of the named 0° template.
      def force_unique_definition!(inst, type = nil, height_key = nil)
        return nil unless inst && inst.valid?
        defn = inst.definition
        type = Attributes.get(inst, Constants::KEY_TYPE) if type.nil?
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT) if height_key.nil?
        needs = shared_template?(defn, type, height_key) || defn.instances.size > 1
        return defn unless needs

        model = inst.model
        temp = nil
        if shared_template?(defn, type, height_key) && defn.instances.size <= 1
          temp = model.active_entities.add_instance(defn, Geom::Transformation.new)
        end
        inst.make_unique
        defn = inst.definition
        if shared_template?(defn, type, height_key)
          defn.name = "#{definition_name(type, height_key)} Flex"
        end
        defn
      ensure
        if temp && temp.valid?
          temp.erase!
        end
      end

      # graphic_height_mm = HEIGHTS_MM entry (overall panel height).
      def build_starter!(defn, graphic_height_mm, flex_angle_deg = 0.0)
        ents = defn.entities
        hinge = hinge_center_local
        free = end_post_center_local(flex_angle_deg)
        tip_mm = post_tip_height_mm(graphic_height_mm)
        add_post_box!(ents, center: hinge, height_mm: tip_mm, label: GROUP_POST_A, yaw_deg: 0.0)
        add_post_box!(ents, center: free, height_mm: tip_mm, label: GROUP_POST_B, yaw_deg: flex_angle_deg)
        add_bay_panels!(ents, hinge, free, flex_angle_deg, graphic_height_mm)
      end

      # Extension bay: one post+foot only. Under RH ψ=180° Place, growth prepends at
      # the anchor hinge so the definition hinge is the graphic-front RIGHT / continue
      # tip (product "free end" of the wall). PostNew MUST be at hinge — free local is
      # the shared join with the prior bay (viewer LEFT of this bay). Place transforms
      # + wall_graph stay unchanged. Verified by test_v0139_fixes place simulation:
      # after starter + N extensions, rightmost world tip has PostNew.
      def build_extension!(defn, graphic_height_mm, flex_angle_deg = 0.0)
        ents = defn.entities
        hinge = hinge_center_local
        free = end_post_center_local(flex_angle_deg)
        tip_mm = post_tip_height_mm(graphic_height_mm)
        add_post_box!(ents, center: hinge, height_mm: tip_mm, label: GROUP_POST_NEW, yaw_deg: 0.0)
        add_bay_panels!(ents, hinge, free, flex_angle_deg, graphic_height_mm)
      end

      def hinge_center_local
        Geom::Point3d.new(Constants::HALF_POST_MM.mm, 0, 0)
      end

      # Free post from fixed-length graphic (flats + arc). Chord shrinks with |flex|.
      def end_post_center_local(flex_angle_deg)
        hinge = hinge_center_local
        ang = flex_angle_deg.to_f
        half = Constants::HALF_POST_MM.mm
        mid_len = (Constants::GRAPHIC_BAY_MM - 2.0 * Constants::HALF_POST_MM).mm
        t0 = Geom::Vector3d.new(1, 0, 0)

        if ang.abs < 0.5
          return offset_point(hinge, t0, Constants::BAY_CENTER_MM.mm)
        end

        theta = ang.degrees
        radius = mid_len / theta # signed
        s = offset_point(hinge, t0, half)
        delta = Geom::Vector3d.new(
          radius * Math.sin(theta),
          radius * (1.0 - Math.cos(theta)),
          0
        )
        e = Geom::Point3d.new(s.x + delta.x, s.y + delta.y, 0)
        t1 = rotate_xy(t0, ang)
        t1.length = 1
        offset_point(e, t1, half)
      end

      def open_end_local_point(flex_angle_deg = 0.0)
        end_post_center_local(flex_angle_deg)
      end

      def outgoing_local_axes(flex_angle_deg)
        theta = flex_angle_deg.to_f.degrees
        xaxis = Geom::Vector3d.new(Math.cos(theta), Math.sin(theta), 0)
        zaxis = Geom::Vector3d.new(0, 0, 1)
        yaxis = zaxis.cross(xaxis)
        [xaxis, yaxis, zaxis]
      end

      def world_open_end(inst)
        flex = Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f
        open_end_local_point(flex).transform(inst.transformation)
      end

      def world_hinge_end(inst)
        hinge_center_local.transform(inst.transformation)
      end

      # Plan unit vector pointing to the viewer's RIGHT when standing in front of
      # the graphic looking at it. Graphic front normal = instance +Y; look = −Y;
      # right = look × +Z. Under RH ψ=180° Place this is world +X (not −X).
      def graphic_front_right_vector(inst)
        return Geom::Vector3d.new(1, 0, 0) unless inst && inst.valid?
        ny = inst.transformation.yaxis
        look_x = -ny.x.to_f
        look_y = -ny.y.to_f
        # look × +Z = (look_y, −look_x, 0)
        rx = look_y
        ry = -look_x
        len = Math.hypot(rx, ry)
        return Geom::Vector3d.new(1, 0, 0) if len < 1e-12
        Geom::Vector3d.new(rx / len, ry / len, 0)
      end

      def plan_dot(point, vec)
        point.x.to_f * vec.x.to_f + point.y.to_f * vec.y.to_f
      end

      # Which outer tip of this module is graphic-front RIGHT (:free or :hinge)?
      # ψ=180° starter: free tip is world −X = viewer LEFT → :hinge (viewer RIGHT).
      def module_continue_end_side(inst)
        right = graphic_front_right_vector(inst)
        free_pt = world_open_end(inst)
        hinge_pt = world_hinge_end(inst)
        plan_dot(free_pt, right) >= plan_dot(hinge_pt, right) ? :free : :hinge
      end

      def world_continue_end(inst, side = nil)
        side = module_continue_end_side(inst) if side.nil?
        side.to_s == 'hinge' ? world_hinge_end(inst) : world_open_end(inst)
      end

      # Place Extension attach transform at the graphic-front-right tip.
      # :free → existing free-post join (append). :hinge → free-of-new joins
      # hinge-of-anchor (prepend) so growth stays on viewer right under ψ=180°.
      def world_extension_placement(inst, side = nil)
        side = module_continue_end_side(inst) if side.nil?
        if side.to_s == 'hinge'
          world_extension_placement_at_hinge(inst)
        else
          world_extension_placement_at_free(inst)
        end
      end

      def world_extension_placement_at_free(inst)
        flex = Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f
        atr = inst.transformation
        x_loc, y_loc, z_loc = outgoing_local_axes(flex)
        xaxis = x_loc.transform(atr)
        yaxis = y_loc.transform(atr)
        zaxis = z_loc.transform(atr)
        xaxis.length = 1
        yaxis.length = 1
        zaxis.length = 1
        open_pt = open_end_local_point(flex).transform(atr)
        back = xaxis.clone
        back.length = Constants::HALF_POST_MM.mm
        origin = open_pt - back
        origin = Geom::Point3d.new(origin.x, origin.y, Floorspace.module_base_z(inst.model))
        Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
      end

      # New module free post coincides with anchor hinge; same RH axes as anchor.
      # Under ψ=180° this extends the wall toward world +X (graphic-front right).
      def world_extension_placement_at_hinge(inst)
        atr = inst.transformation
        xaxis = atr.xaxis.clone
        yaxis = atr.yaxis.clone
        zaxis = atr.zaxis.clone
        xaxis.length = 1
        yaxis.length = 1
        zaxis.length = 1
        hinge_pt = world_hinge_end(inst)
        fl = end_post_center_local(0.0)
        origin = Geom::Point3d.new(
          hinge_pt.x - xaxis.x * fl.x - yaxis.x * fl.y,
          hinge_pt.y - xaxis.y * fl.x - yaxis.y * fl.y,
          Floorspace.module_base_z(inst.model)
        )
        Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
      end

      def add_post_box!(ents, center:, height_mm:, label:, yaw_deg: 0.0)
        s = Constants::POST_SECTION_MM.mm
        # height_mm = post tip Z. Bottom sits on foot top (FOOT_THICKNESS_MM).
        z0 = FOOT_THICKNESS_MM.mm
        h = height_mm.to_f.mm
        group = ents.add_group
        group.name = label
        add_axis_aligned_box!(
          group.entities,
          Geom::Point3d.new(-s / 2.0, -s / 2.0, z0),
          Geom::Point3d.new(s / 2.0, s / 2.0, h),
          Sketchup::Color.new(*POST_COLOR)
        )
        yaw = yaw_deg.to_f.degrees
        rot = Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          Geom::Vector3d.new(0, 0, 1),
          yaw
        )
        move = Geom::Transformation.translation(Geom::Vector3d.new(center.x, center.y, 0))
        group.transform!(move * rot)
        add_base_support!(ents, center: center, yaw_deg: yaw_deg, label: label)
        group
      end

      # Wave foot under a post — detailed mesh from Wave_foot.STEP (fallback: outline).
      # Length along local +Y (perp to wall/flexi-link); same yaw as the post so
      # free-end feet swing with flex. Bottom on Z=0; thickness = FOOT_THICKNESS_MM.
      def add_base_support!(ents, center:, yaw_deg: 0.0, label: nil)
        color = Sketchup::Color.new(*BASE_COLOR)

        group = ents.add_group
        group.name = label ? "#{GROUP_BASE}_#{label}" : GROUP_BASE
        ge = group.entities

        unless embed_foot_mesh!(ge, color)
          thick = FOOT_THICKNESS_MM.mm
          pts = FOOT_OUTLINE_MM.map { |x, y| Geom::Point3d.new(x.to_f.mm, y.to_f.mm, 0) }
          face = ge.add_face(pts)
          if face
            face.reverse! if face.normal.z < 0
            face.pushpull(thick)
            ge.grep(Sketchup::Face).each { |f| tint_face!(f, color) }
          end
        end

        yaw = yaw_deg.to_f.degrees
        rot = Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          Geom::Vector3d.new(0, 0, 1),
          yaw
        )
        move = Geom::Transformation.translation(Geom::Vector3d.new(center.x, center.y, 0))
        group.transform!(move * rot)
        group
      rescue StandardError
        group.erase! if defined?(group) && group && group.valid?
        nil
      end

      def embed_foot_mesh!(ents, color)
        model = entities_model(ents)
        return false unless model
        foot_defn = MeshImport.definition_from_obj!(
          model,
          DEFN_FOOT,
          OBJ_FOOT,
          color: color
        )
        return false unless foot_defn && foot_defn.entities.size > 0
        # Force Z thickness to FOOT_THICKNESS_MM even if a cached/older OBJ differs.
        tr = foot_thickness_scale_transform(foot_defn)
        ents.add_instance(foot_defn, tr)
        true
      rescue StandardError
        false
      end

      # Scale-only transform mapping foot_defn Z span → FOOT_THICKNESS_MM (mm).
      # Identity when the bundled OBJ is already authored at that thickness.
      def foot_thickness_scale_transform(foot_defn)
        bb = foot_defn.bounds
        z0 = bb.min.z.to_f
        z1 = bb.max.z.to_f
        span = z1 - z0
        target = FOOT_THICKNESS_MM.mm.to_f
        return Geom::Transformation.new if span < 1e-9
        sx = 1.0
        sy = 1.0
        sz = target / span
        # Scale about Z=0 so the sole stays on the floor; shift if z0 ≠ 0.
        scale = Geom::Transformation.scaling(Geom::Point3d.new(0, 0, 0), sx, sy, sz)
        return scale if z0.abs < 1e-9
        shift = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -z0 * sz))
        shift * scale
      end

      def entities_model(ents)
        return nil unless ents
        parent = ents.parent
        return parent if parent.is_a?(Sketchup::Model)
        return parent.model if parent.respond_to?(:model)
        nil
      end

      def add_bay_panels!(ents, hinge, free, flex_angle_deg, graphic_height_mm)
        g = graphic_height_mm.to_f
        z_bot = graphic_z_bot_mm.mm
        z_top = graphic_z_top_mm(g).mm
        ang = flex_angle_deg.to_f

        # Graphic on FRONT face; flats truly planar on BOTH posts.
        # Continuous solid panel (soft+smooth vertical seams); thickness + clearance
        # entirely in front of the face path so posts do not show through.
        # v0.1.39: HEIGHTS_MM = panel height; z_bot clears foot; z_top = z_bot + HEIGHTS.
        graphic_path = face_path(hinge, free, ang, Constants::HALF_POST_MM.mm)
        add_continuous_slab_along!(
          ents,
          graphic_path,
          z_bot: z_bot,
          z_top: z_top,
          thickness_mm: GRAPHIC_THICKNESS_MM,
          name: GROUP_GRAPHIC,
          color: Sketchup::Color.new(230, 235, 245),
          front_biased: true,
          front_clearance_mm: GRAPHIC_FRONT_CLEARANCE_MM
        )

        # Flexi-link BOTTOM + BEHIND; length follows back-offset arc (unchanged).
        # Solid nudged toward graphic by BEAM_TOWARD_GRAPHIC_MM (draw bias only).
        beam_path = face_path(hinge, free, ang, -Constants::HALF_POST_MM.mm)
        z0 = BEAM_Z_BOT_MM.mm
        z1 = z0 + Constants::BEAM_THICKNESS_MM.mm
        add_continuous_slab_along!(
          ents,
          beam_path,
          z_bot: z0,
          z_top: z1,
          thickness_mm: Constants::BEAM_DEPTH_MM,
          name: GROUP_BEAM,
          color: Sketchup::Color.new(120, 140, 180),
          front_biased: false,
          normal_shift_mm: BEAM_TOWARD_GRAPHIC_MM
        )
      end

      # Flat–arc–flat path at a constant left-normal offset from the centreline.
      # offset > 0 = front face; offset < 0 = back (behind graphic).
      def face_path(p0, p1, flex_angle_deg, offset, segments = ARC_SEGMENTS)
        p0 = Geom::Point3d.new(p0.x, p0.y, 0)
        p1 = Geom::Point3d.new(p1.x, p1.y, 0)
        ang = flex_angle_deg.to_f
        half = Constants::HALF_POST_MM.mm
        mid_len = (Constants::GRAPHIC_BAY_MM - 2.0 * Constants::HALF_POST_MM).mm
        off = offset

        t0 = Geom::Vector3d.new(1, 0, 0)
        t1 = rotate_xy(t0, ang)
        t0.length = 1
        t1.length = 1
        n0 = left_normal(t0)
        n1 = left_normal(t1)

        # Explicit flats on each post face — independent of arc sampling.
        a0 = offset_point(p0, n0, off)
        a1 = offset_point(a0, t0, half)
        b1 = offset_point(p1, n1, off)
        b0 = offset_point(b1, t1, -half)

        pts = []
        flat_segs = 4
        (0..flat_segs).each { |i| pts << lerp_xy(a0, a1, i / flat_segs.to_f) }

        if ang.abs < 0.5
          (1..flat_segs).each { |i| pts << lerp_xy(a1, b0, i / flat_segs.to_f) }
        else
          theta = ang.degrees
          r_center = mid_len / theta
          r_path = r_center - off
          s_center = offset_point(p0, t0, half)
          c = offset_point(s_center, n0, r_center)
          v0 = Geom::Vector3d.new(s_center.x - c.x, s_center.y - c.y, 0)
          mid_segs = [segments, 8].max
          (1...mid_segs).each do |i|
            t = i / mid_segs.to_f
            vi = rotate_xy(v0, ang * t)
            scale = r_path / r_center
            pts << Geom::Point3d.new(c.x + vi.x * scale, c.y + vi.y * scale, 0)
          end
          pts << b0 unless points_nearly_equal?(pts.last, b0)
        end

        (1..flat_segs).each { |i| pts << lerp_xy(b0, b1, i / flat_segs.to_f) }
        pts
      end

      def left_normal(tangent)
        Geom::Vector3d.new(-tangent.y, tangent.x, 0)
      end

      def lerp_xy(a, b, t)
        Geom::Point3d.new(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          0
        )
      end

      def rotate_xy(vec, deg)
        r = deg.to_f.degrees
        Geom::Vector3d.new(
          vec.x * Math.cos(r) - vec.y * Math.sin(r),
          vec.x * Math.sin(r) + vec.y * Math.cos(r),
          0
        )
      end

      def offset_point(point, direction, distance)
        d = direction.clone
        return Geom::Point3d.new(point.x, point.y, 0) if d.length < 1e-9
        d.length = distance
        Geom::Point3d.new(point.x + d.x, point.y + d.y, point.z)
      end

      def points_nearly_equal?(a, b, eps = 1e-6)
        return false unless a && b
        (a.x - b.x).abs < eps && (a.y - b.y).abs < eps
      end

      # Continuous vertical slab along a plan path (same path math as before).
      # front_biased: thickness entirely along +left-normal (in front of path) so
      # posts stay behind the graphic face. front_clearance_mm lifts the back face
      # off the path to avoid z-fighting with the post. Otherwise thickness is centered.
      # normal_shift_mm: translate both faces along +left-normal (beam toward graphic).
      def add_continuous_slab_along!(ents, plan_pts, z_bot:, z_top:, thickness_mm:, name:, color:, front_biased: false, front_clearance_mm: 0.0, normal_shift_mm: 0.0)
        pts = dedupe_plan_points(plan_pts)
        return if pts.nil? || pts.size < 2

        t_mm = thickness_mm.to_f.mm
        half_t = t_mm / 2.0
        clear = front_clearance_mm.to_f.mm
        shift = normal_shift_mm.to_f.mm
        group = ents.add_group
        group.name = name
        ge = group.entities

        front_bot = []
        back_bot = []
        pts.each_with_index do |p, i|
          tan = path_tangent_at(pts, i)
          n = left_normal(tan)
          n.length = 1
          if front_biased
            # Path sits on post front; panel starts just clear of it, grows +front.
            bx = n.x * clear
            by = n.y * clear
            fx = n.x * (clear + t_mm)
            fy = n.y * (clear + t_mm)
            front_bot << Geom::Point3d.new(p.x + fx, p.y + fy, z_bot)
            back_bot  << Geom::Point3d.new(p.x + bx, p.y + by, z_bot)
          else
            fx = n.x * (half_t + shift)
            fy = n.y * (half_t + shift)
            bx = n.x * (-half_t + shift)
            by = n.y * (-half_t + shift)
            front_bot << Geom::Point3d.new(p.x + fx, p.y + fy, z_bot)
            back_bot  << Geom::Point3d.new(p.x + bx, p.y + by, z_bot)
          end
        end

        front_top = front_bot.map { |p| Geom::Point3d.new(p.x, p.y, z_top) }
        back_top  = back_bot.map  { |p| Geom::Point3d.new(p.x, p.y, z_top) }

        nseg = pts.size - 1
        (0...nseg).each do |i|
          j = i + 1
          f1 = ge.add_face(front_bot[i], front_bot[j], front_top[j], front_top[i])
          f2 = ge.add_face(back_bot[j], back_bot[i], back_top[i], back_top[j])
          f3 = ge.add_face(front_bot[i], back_bot[i], back_bot[j], front_bot[j])
          f4 = ge.add_face(front_top[i], front_top[j], back_top[j], back_top[i])
          [f1, f2, f3, f4].each { |f| tint_face!(f, color) }
        end

        tint_face!(ge.add_face(front_bot[0], back_bot[0], back_top[0], front_top[0]), color)
        tint_face!(ge.add_face(front_bot[-1], front_top[-1], back_top[-1], back_bot[-1]), color)

        soften_longitudinal_seams!(ge)
        group
      rescue StandardError
        group.erase! if defined?(group) && group && group.valid?
        fallback_pts = plan_pts
        shift_mm = normal_shift_mm.to_f
        if !front_biased && shift_mm.abs > 1e-9
          fallback_pts = shift_plan_path_along_left_normal(plan_pts, shift_mm.mm)
        end
        add_vertical_slab_along!(
          ents, fallback_pts,
          z_bot: z_bot, z_top: z_top, thickness_mm: thickness_mm, name: name, color: color
        )
      end

      def shift_plan_path_along_left_normal(plan_pts, distance)
        pts = dedupe_plan_points(plan_pts)
        pts.each_with_index.map do |p, i|
          n = left_normal(path_tangent_at(pts, i))
          n.length = 1
          Geom::Point3d.new(p.x + n.x * distance, p.y + n.y * distance, 0)
        end
      end

      def soften_longitudinal_seams!(ents)
        # Soft+smooth segment seams so the panel reads as one continuous face.
        # v0.1.14 softened only near-horizontal edges; the visible ribs are the
        # upright edges between adjacent front/back quads — soften those too.
        # Keep short thickness (front↔back) edges hard for a crisp slab silhouette.
        ents.grep(Sketchup::Edge).each do |e|
          next unless e.valid?
          next if e.faces.size < 2
          d = e.line[1]
          next if d.length < 1e-9
          d = d.clone
          d.normalize!
          len_mm = e.length.to_f * 25.4 # SketchUp Length → mm
          if d.z.abs > 0.65
            # Vertical segment ribs between quads.
            e.soft = true
            e.smooth = true
          elsif d.z.abs < 0.35 && len_mm > 8.0
            # Long path-wise edges on front/back/top/bottom (not short thickness).
            e.soft = true
            e.smooth = true
          end
        end
      rescue StandardError
        nil
      end

      def dedupe_plan_points(plan_pts)
        return [] if plan_pts.nil?
        out = []
        plan_pts.each do |p|
          pt = Geom::Point3d.new(p.x, p.y, 0)
          next if !out.empty? && points_nearly_equal?(out.last, pt)
          out << pt
        end
        out
      end

      def path_tangent_at(pts, i)
        v = if i <= 0
              Geom::Vector3d.new(pts[1].x - pts[0].x, pts[1].y - pts[0].y, 0)
            elsif i >= pts.size - 1
              Geom::Vector3d.new(pts[-1].x - pts[-2].x, pts[-1].y - pts[-2].y, 0)
            else
              Geom::Vector3d.new(pts[i + 1].x - pts[i - 1].x, pts[i + 1].y - pts[i - 1].y, 0)
            end
        if v.length < 1e-9
          Geom::Vector3d.new(1, 0, 0)
        else
          v.normalize!
          v
        end
      end

      # Legacy per-segment boxes (fallback only). Prefer add_continuous_slab_along!.
      def add_vertical_slab_along!(ents, plan_pts, z_bot:, z_top:, thickness_mm:, name:, color:)
        return if plan_pts.nil? || plan_pts.size < 2
        half_t = (thickness_mm.to_f / 2.0).mm
        group = ents.add_group
        group.name = name
        ge = group.entities

        (0...plan_pts.size - 1).each do |i|
          a = plan_pts[i]
          b = plan_pts[i + 1]
          tangential = Geom::Vector3d.new(b.x - a.x, b.y - a.y, 0)
          next if tangential.length < 1e-6
          tangential.normalize!
          normal = Geom::Vector3d.new(-tangential.y, tangential.x, 0)
          normal.length = half_t

          bl = Geom::Point3d.new(a.x + normal.x, a.y + normal.y, z_bot)
          br = Geom::Point3d.new(a.x - normal.x, a.y - normal.y, z_bot)
          tr = Geom::Point3d.new(b.x - normal.x, b.y - normal.y, z_bot)
          tl = Geom::Point3d.new(b.x + normal.x, b.y + normal.y, z_bot)
          bl_t = Geom::Point3d.new(bl.x, bl.y, z_top)
          br_t = Geom::Point3d.new(br.x, br.y, z_top)
          tr_t = Geom::Point3d.new(tr.x, tr.y, z_top)
          tl_t = Geom::Point3d.new(tl.x, tl.y, z_top)
          add_box_faces!(ge, [bl, br, tr, tl], [bl_t, br_t, tr_t, tl_t], color)
        end
        group
      end

      def add_axis_aligned_box!(ents, pmin, pmax, color)
        x0, y0, z0 = pmin.x, pmin.y, pmin.z
        x1, y1, z1 = pmax.x, pmax.y, pmax.z
        bot = [
          Geom::Point3d.new(x0, y0, z0),
          Geom::Point3d.new(x1, y0, z0),
          Geom::Point3d.new(x1, y1, z0),
          Geom::Point3d.new(x0, y1, z0)
        ]
        top = [
          Geom::Point3d.new(x0, y0, z1),
          Geom::Point3d.new(x1, y0, z1),
          Geom::Point3d.new(x1, y1, z1),
          Geom::Point3d.new(x0, y1, z1)
        ]
        add_box_faces!(ents, bot, top, color)
      end

      def add_box_faces!(ents, bot, top, color)
        faces = []
        faces << ents.add_face(bot[0], bot[1], bot[2], bot[3])
        faces << ents.add_face(top[0], top[3], top[2], top[1])
        4.times do |i|
          j = (i + 1) % 4
          faces << ents.add_face(bot[i], bot[j], top[j], top[i])
        end
        faces.each { |f| tint_face!(f, color) }
      rescue StandardError
        nil
      end

      def tint_face!(face, color)
        return unless face
        face.material = color
        face.back_material = color
      rescue StandardError
        nil
      end

      def extension_origin_at_open_end(world_open_end_point)
        offset = Geom::Vector3d.new(Constants::HALF_POST_MM.mm, 0, 0)
        world_open_end_point - offset
      end

      # RH ψ=180° about Z (det +1): graphic local +Y → world −Y (faces floorspace /
      # user). Local free tip (+X) → world −X = viewer LEFT when looking at the
      # graphic. Place Extension therefore attaches at the hinge / root tip
      # (viewer RIGHT / world +X side) via world_extension_placement(:hinge) —
      # not a plan-mirror (det −1 broke Fix Right hinge freeze in 0.1.31–32).
      def starter_placement_transform(origin)
        Geom::Transformation.new(
          Geom::Vector3d.new(-1, 0, 0),
          Geom::Vector3d.new(0, -1, 0),
          Geom::Vector3d.new(0, 0, 1),
          origin
        )
      end
    end
  end
end
