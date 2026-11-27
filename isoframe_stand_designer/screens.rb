# frozen_string_literal: true
# Media Screen Small / Large — Richard’s SKPs on a straight Wave starter or
# extension. Sibling instance (like tables). Flexilink STAYS. Straight only.
#
# v0.1.75 locks:
#   - Centre of screen 1500 mm above floor (module Z = floor top)
#   - Screen 50 mm in front of graphic outer face
#   - Centred on the bay (midpoint of hinge/free posts)
#   - Soft edges via Geometry.soften_definition_edges!
# v0.1.76: replace oversized (~2000 m) Samsung SKPs with Richard’s new
# Media_screen_-_{small,Large}.skp. Fresh defn names. Strip Sree scale figure
# from Large. Metres-correct bake: if largest axis > 10 m, scale ×0.001
# (mm-authored-as-metres) up to 3× — same class of fix as Oval upright bake.
# v0.1.77: bake ONLY from the loaded SKP root (do not scan the whole model —
# that reused Small when placing Large). LOCK landscape: +90° about +Y so
# portrait SKPs become landscape. Attach position locks unchanged.

module ISOframe
  module StandDesigner
    module Screens
      module_function

      REGISTRY = {
        'small' => {
          kind: 'small',
          label: 'Media Screen Small',
          skp_file: 'Media_screen_-_small.skp',
          # Fresh name so dealers drop any cached v75–v76 bake.
          defn_name: 'ISOframe Media Screen Small v77',
          instance_name: 'ISOframe Media Screen Small'
        },
        'large' => {
          kind: 'large',
          label: 'Media Screen Large',
          skp_file: 'Media_screen_-_Large.skp',
          defn_name: 'ISOframe Media Screen Large v77',
          instance_name: 'ISOframe Media Screen Large'
        }
      }.freeze

      # LOCKED v0.1.75 — do not change unless Richard asks.
      SCREEN_CENTER_Z_MM = 1500.0
      SCREEN_IN_FRONT_OF_GRAPHIC_MM = 50.0
      # Exhibition screen upper bound. Anything larger is almost certainly a
      # units mistake (mm numbers stored as metres → ~1000× too big).
      SANE_MAX_EXTENT_MM = 10_000.0
      MM_AS_METRES_SCALE = 0.001
      MAX_SCALE_CORRECTIONS = 3
      # LOCKED v0.1.77 — SKPs arrive portrait; +90° about +Y → landscape
      # (width along X, height along Z). Thin axis stays Y (faces room).
      LANDSCAPE_ROT_Y_DEG = 90.0

      def label_for(kind)
        entry = REGISTRY[kind.to_s]
        entry ? entry[:label] : kind.to_s
      end

      def screen_on?(inst)
        !screen_type(inst).empty?
      end

      def screen_type(inst)
        Attributes.get(inst, Constants::KEY_SCREEN_TYPE, '').to_s
      end

      def screen_instance?(ent)
        return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
        kind = Attributes.get(ent, Constants::KEY_SCREEN_KIND, '').to_s
        !kind.empty?
      end

      def straight?(inst)
        Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f.abs < 0.5
      end

      def toggle_selected!(kind = 'small')
        return unless License.require_active!
        model = Sketchup.active_model
        insts = SelectionUtil.wave_modules_in_selection(model)
        if insts.empty?
          model.selection.each do |e|
            next unless screen_instance?(e)
            host = host_for_screen(e)
            insts << host if host
          end
          insts.uniq!
        end
        if insts.empty?
          UI.messagebox(
            "Select a straight Wave starter or extension, then #{label_for(kind)}."
          )
          return false
        end

        model.start_operation("ISOframe #{label_for(kind)}", true)
        begin
          attached = 0
          removed = 0
          skipped = 0
          insts.each do |inst|
            case toggle_one!(inst, kind)
            when :attached then attached += 1
            when :removed then removed += 1
            else skipped += 1
            end
          end
          model.commit_operation

          if attached + removed == 0 && skipped > 0
            UI.messagebox('Media screens only attach to straight modules (flex = 0°). Straighten first.')
            return false
          end
          bits = []
          bits << "+#{attached}" if attached > 0
          bits << "−#{removed}" if removed > 0
          bits << "skipped #{skipped} bent" if skipped > 0
          Sketchup.status_text = "#{label_for(kind)}: #{bits.join(' / ')}"
          true
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Media Screen failed:\n#{e.message}")
          false
        end
      end

      def toggle_one!(inst, kind)
        kind = kind.to_s
        return false unless REGISTRY.key?(kind)
        return false unless SelectionUtil.wave_module?(inst)

        current = screen_type(inst)
        if current == kind
          remove!(inst)
          return :removed
        end
        return :bent unless straight?(inst)

        attach!(inst, kind)
        :attached
      end

      def attach!(inst, kind)
        kind = kind.to_s
        entry = REGISTRY[kind]
        raise ArgumentError, "Unknown screen: #{kind}" unless entry
        raise 'Media screens only attach to straight modules' unless straight?(inst)

        erase_screen_instances_for_host!(inst)
        Attributes.set(inst, Constants::KEY_SCREEN_TYPE, kind)
        # Do NOT erase flexilink. Do NOT rebuild host definition.
        place_screen_instance!(inst, entry)
        Constraints.ensure_module_on_floor!(inst)
        inst
      end

      def remove!(inst)
        return unless inst && inst.valid?
        erase_screen_instances_for_host!(inst)
        Attributes.set(inst, Constants::KEY_SCREEN_TYPE, '')
        Constraints.ensure_module_on_floor!(inst)
        inst
      end

      def place_screen_instance!(host, entry)
        model = host.model
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        if mid.empty?
          mid = "mod_#{host.entityID}_#{Time.now.to_i}"
          Attributes.set(host, Constants::KEY_MODULE_ID, mid)
        end

        defn = screen_definition!(model, entry)
        local = attach_local_transform
        world_tr = host.transformation * local
        inst = model.active_entities.add_instance(defn, world_tr)
        inst.name = entry[:instance_name]
        Attributes.set(inst, Constants::KEY_SCREEN_KIND, entry[:kind].to_s)
        Attributes.set(inst, Constants::KEY_SCREEN_HOST, mid.to_s)
        puts "[ISOframe] Media screen placed kind=#{entry[:kind]} " \
             "local_mm=#{(local.origin.x / 1.mm).round(1)}," \
             "#{(local.origin.y / 1.mm).round(1)}," \
             "#{(local.origin.z / 1.mm).round(1)}"
        inst
      end

      def reposition_screen_for_host!(host)
        return unless host && host.valid?
        return unless screen_on?(host)
        screen = find_screen_instance_for_host(host)
        return unless screen && screen.valid?
        screen.transformation = host.transformation * attach_local_transform
        screen
      rescue StandardError => e
        puts "[ISOframe] reposition_screen_for_host! failed: #{e.message}"
        nil
      end

      def follow_hosts!(hosts)
        Array(hosts).each do |host|
          next unless host && host.valid?
          next unless SelectionUtil.wave_module?(host)
          next unless screen_on?(host)
          reposition_screen_for_host!(host)
        end
        nil
      rescue StandardError => e
        puts "[ISOframe] Screens.follow_hosts! failed: #{e.message}"
        nil
      end

      # Graphic outer face Y + 50 mm; bay midpoint X; centre Z = 1500 mm.
      def attach_local_transform
        hinge = Geometry.hinge_center_local
        free = Geometry.end_post_center_local(0.0)
        cx = (hinge.x + free.x) * 0.5
        graphic_front_y =
          Constants::HALF_POST_MM.mm +
          Geometry::GRAPHIC_FRONT_CLEARANCE_MM.mm +
          Geometry::GRAPHIC_THICKNESS_MM.mm
        cy = graphic_front_y + SCREEN_IN_FRONT_OF_GRAPHIC_MM.mm
        cz = SCREEN_CENTER_Z_MM.mm
        Geom::Transformation.new(Geom::Point3d.new(cx, cy, cz))
      end

      def screen_definition!(model, entry)
        defn_name = entry[:defn_name]
        existing = model.definitions[defn_name]
        if existing && !existing.image? && existing.entities.size > 0
          Geometry.soften_definition_edges!(existing)
          return existing
        end

        skp_name = entry[:skp_file].to_s
        path = MeshImport.model_path(skp_name)
        raise "Missing bundled SKP: #{skp_name}" unless File.file?(path)
        # Guard: Large must never resolve to the small file (and vice versa).
        bas = File.basename(path)
        raise "Screen SKP path mismatch: expected #{skp_name}, got #{bas}" unless bas == skp_name

        root = model.definitions.load(path)
        raise "Failed to load #{skp_name}" unless root

        # Large SKP may still carry the SketchUp Sree sampler — strip before bake.
        strip_scale_figures_from_definition!(root)

        # Bake ONLY this SKP’s root. Do not scan model.definitions — a prior
        # Small bake is named “Media Screen…” and would win the score for Large.
        src = root
        faces = begin
          count_faces_deep(src.entities, 0)
        rescue StandardError
          0
        end
        raise "No media screen geometry in #{skp_name}" if faces < 1

        defn = existing || model.definitions.add(defn_name)
        defn.entities.clear! if defn.entities.size > 0

        local = orient_screen_to_bake(src)
        local = landscape_transform(src, local)
        local = metres_correct_transform(src, local)
        inst = defn.entities.add_instance(src, local)
        inst.name = entry[:instance_name] if inst.respond_to?(:name=)
        Geometry.soften_definition_edges!(defn)
        dims = oriented_extent_mm(src, local)
        puts "[ISOframe] Media screen bake kind=#{entry[:kind]} skp=#{skp_name} " \
             "src=#{src.name.inspect} landscape_y=#{LANDSCAPE_ROT_Y_DEG}° " \
             "extent_mm=#{dims.map { |v| v.round(1) }.inspect}"
        defn
      end

      def strip_scale_figures_from_definition!(defn)
        return unless defn && defn.valid?
        defn.entities.to_a.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          n = if e.is_a?(Sketchup::ComponentInstance)
                e.definition.name.to_s
              else
                e.name.to_s
              end
          next unless n =~ /\bsree\b/i || n =~ /scale\s*figure/i
          e.erase! if e.valid?
        end
      rescue StandardError => e
        puts "[ISOframe] strip_scale_figures_from_definition! failed: #{e.message}"
      end

      def count_faces_deep(entities, depth)
        return 0 if entities.nil? || depth > 8
        n = entities.grep(Sketchup::Face).size
        entities.each do |e|
          if e.is_a?(Sketchup::Group)
            n += count_faces_deep(e.entities, depth + 1)
          elsif e.is_a?(Sketchup::ComponentInstance)
            n += count_faces_deep(e.definition.entities, depth + 1)
          end
        end
        n
      end

      # Bake so screen is vertical (Z up), thin axis ≈ Y (faces room/+Y), centre at origin.
      def orient_screen_to_bake(src)
        bb = src.bounds
        return Geom::Transformation.new if bb.nil? || bb.empty?

        dx = (bb.max.x - bb.min.x).abs
        dy = (bb.max.y - bb.min.y).abs
        dz = (bb.max.z - bb.min.z).abs
        origin = Geom::Point3d.new(0, 0, 0)
        rot = Geom::Transformation.new

        # Y-up / lying flat: tallest along Y or thinnest along Z → +90° about X.
        if dy >= dx && dy >= dz
          rot = Geom::Transformation.rotation(
            origin, Geom::Vector3d.new(1, 0, 0), 90.0 * Math::PI / 180.0
          )
        elsif dz <= dx && dz <= dy
          rot = Geom::Transformation.rotation(
            origin, Geom::Vector3d.new(1, 0, 0), 90.0 * Math::PI / 180.0
          )
        end

        # After upright, ensure thin axis is Y (screen faces ±Y). If thin is X, +90° Z.
        corners = bound_corners(bb).map { |p| p.transform(rot) }
        dx2 = corners.map(&:x).minmax.then { |a, b| (b - a).abs }
        dy2 = corners.map(&:y).minmax.then { |a, b| (b - a).abs }
        dz2 = corners.map(&:z).minmax.then { |a, b| (b - a).abs }
        if dx2 <= dy2 && dx2 <= dz2
          rot = Geom::Transformation.rotation(
            origin, Geom::Vector3d.new(0, 0, 1), 90.0 * Math::PI / 180.0
          ) * rot
        end

        center_at_origin_after(src, rot)
      end

      # LOCKED v0.1.77 — portrait SKP → landscape via +90° about +Y (thin/face axis).
      def landscape_transform(src, tr)
        origin = Geom::Point3d.new(0, 0, 0)
        y_axis = Geom::Vector3d.new(0, 1, 0)
        rot_y = Geom::Transformation.rotation(
          origin, y_axis, LANDSCAPE_ROT_Y_DEG * Math::PI / 180.0
        )
        center_at_origin_after(src, rot_y * tr)
      end

      # If SKP geometry is ~1000× too big (mm numbers as metres → kilometres),
      # scale down until largest axis ≤ 10 m. Re-centre after each scale.
      def metres_correct_transform(src, tr)
        MAX_SCALE_CORRECTIONS.times do
          dims = oriented_extent_mm(src, tr)
          max_mm = dims.max
          break if max_mm <= SANE_MAX_EXTENT_MM
          origin = Geom::Point3d.new(0, 0, 0)
          scale = Geom::Transformation.scaling(
            origin, MM_AS_METRES_SCALE, MM_AS_METRES_SCALE, MM_AS_METRES_SCALE
          )
          tr = scale * tr
          puts "[ISOframe] Media screen metres-correct ×#{MM_AS_METRES_SCALE} " \
               "(was max #{max_mm.round(1)} mm)"
        end
        center_at_origin_after(src, tr)
      end

      def oriented_extent_mm(src, tr)
        bb = src.bounds
        return [0.0, 0.0, 0.0] if bb.nil? || bb.empty?
        corners = bound_corners(bb).map { |p| p.transform(tr) }
        dx = corners.map(&:x).minmax.then { |a, b| (b - a).abs } / 1.mm
        dy = corners.map(&:y).minmax.then { |a, b| (b - a).abs } / 1.mm
        dz = corners.map(&:z).minmax.then { |a, b| (b - a).abs } / 1.mm
        [dx, dy, dz]
      end

      def bound_corners(bb)
        [
          Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
          Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
          Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
          Geom::Point3d.new(bb.min.x, bb.max.y, bb.max.z),
          Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.min.y, bb.max.z),
          Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
        ]
      end

      def center_at_origin_after(src, rot)
        bb = src.bounds
        return rot if bb.nil? || bb.empty?
        pts = bound_corners(bb).map { |p| p.transform(rot) }
        cx = pts.map(&:x).minmax.sum * 0.5
        cy = pts.map(&:y).minmax.sum * 0.5
        cz = pts.map(&:z).minmax.sum * 0.5
        sit = Geom::Transformation.translation(Geom::Vector3d.new(-cx, -cy, -cz))
        sit * rot
      end

      def find_screen_instance_for_host(host)
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        return nil if mid.empty?
        host.model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless screen_instance?(e)
          Attributes.get(e, Constants::KEY_SCREEN_HOST).to_s == mid
        end
      end

      def erase_screen_instances_for_host!(host)
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        host.model.active_entities.grep(Sketchup::ComponentInstance).each do |e|
          next unless screen_instance?(e)
          next unless mid.empty? || Attributes.get(e, Constants::KEY_SCREEN_HOST).to_s == mid
          e.erase! if e.valid?
        end
      rescue StandardError
        nil
      end

      def host_for_screen(screen_inst)
        mid = Attributes.get(screen_inst, Constants::KEY_SCREEN_HOST).to_s
        return nil if mid.empty?
        screen_inst.model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless SelectionUtil.wave_module?(e)
          Attributes.get(e, Constants::KEY_MODULE_ID).to_s == mid
        end
      end

      def handle_screen_erased!(model, host_module_id)
        return if host_module_id.to_s.empty?
        host = model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless SelectionUtil.wave_module?(e)
          Attributes.get(e, Constants::KEY_MODULE_ID).to_s == host_module_id.to_s
        end
        return unless host && host.valid?
        return if screen_type(host).empty?
        Attributes.set(host, Constants::KEY_SCREEN_TYPE, '')
      rescue StandardError => e
        puts "[ISOframe] handle_screen_erased! failed: #{e.message}"
      end

      def install_erase_observer!(model)
        return unless model
        @erase_observers ||= {}
        return if @erase_observers[model.object_id]
        obs = ScreenEraseObserver.new
        model.entities.add_observer(obs)
        @erase_observers[model.object_id] = obs
      end

      class ScreenEraseObserver < Sketchup::EntitiesObserver
        def initialize
          @host_by_eid = {}
        end

        def onElementAdded(_entities, entity)
          return unless Screens.screen_instance?(entity)
          mid = Attributes.get(entity, Constants::KEY_SCREEN_HOST).to_s
          @host_by_eid[entity.entityID] = mid unless mid.empty?
        end

        def onElementModified(_entities, entity)
          return unless entity && entity.valid?
          if SelectionUtil.wave_module?(entity) && Screens.screen_on?(entity)
            Screens.reposition_screen_for_host!(entity)
          end
        rescue StandardError
          nil
        end

        def onElementRemoved(_entities, entity_id)
          mid = @host_by_eid.delete(entity_id)
          return if mid.nil? || mid.empty?
          model = Sketchup.active_model
          return unless model
          still = model.active_entities.grep(Sketchup::ComponentInstance).any? do |e|
            Screens.screen_instance?(e) &&
              Attributes.get(e, Constants::KEY_SCREEN_HOST).to_s == mid
          end
          return if still
          Screens.handle_screen_erased!(model, mid)
        rescue StandardError
          nil
        end
      end
    end
  end
end
