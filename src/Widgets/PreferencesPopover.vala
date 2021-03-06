public class PreferencesPopover : Gtk.Popover {
    private enum StylesheetState {
        NONE,
        DEFAULT,
        CUSTOM
    }

    private Preferences prefs;

    private Gtk.FontButton font_btn;

    private Gtk.ListStore schemes_store;
    private Gtk.TreeIter schemes_iter;
    private Gtk.ComboBox scheme_box;

    private Gtk.CheckButton autosave_btn;
    private Gtk.SpinButton autosave_spin;

    private Gtk.ListStore stylesheet_store;
    private Gtk.ComboBox stylesheet_box;
    private Gtk.FileChooserButton stylesheet_chooser;

    private Gtk.Revealer csb_revealer;

    private const string DEFAULT_STYLESHEET = "https://github.com/sindresorhus/github-markdown-css/raw/gh-pages/github-markdown.css";

    public PreferencesPopover (Preferences prefs) {
        this.prefs = prefs;

        setup_ui ();
        setup_events ();
    }

    private void setup_ui () {
        this.border_width = 10;

        var layout = new Gtk.Grid ();
        layout.margin = 10;
        layout.row_spacing = 12;
        layout.column_spacing = 9;
        int row = 0;

        font_btn = new Gtk.FontButton ();
        font_btn.use_font = true;
        font_btn.use_size = true;
        font_btn.halign = Gtk.Align.START;

        if (prefs.editor_font != "") {
            font_btn.set_font_name (prefs.editor_font);
        }

        var font_label = new Gtk.Label.with_mnemonic (_("Editor _font:"));
        font_label.mnemonic_widget = font_btn;
        font_label.halign = Gtk.Align.END;

        layout.attach (font_label, 0, row, 1, 1);
        layout.attach_next_to (font_btn, font_label, Gtk.PositionType.RIGHT, 1, 1);
        row++;

        schemes_store = new Gtk.ListStore (2, typeof (string), typeof (string));

        scheme_box = new Gtk.ComboBox.with_model (schemes_store);
        var scheme_renderer = new Gtk.CellRendererText ();
        scheme_box.pack_start (scheme_renderer, true);
        scheme_box.add_attribute (scheme_renderer, "text", 1);
        scheme_box.halign = Gtk.Align.START;

        var schemes = this.get_source_schemes ();
        int i = 0;
        schemes_iter = {};
        foreach (var scheme in schemes) {
            schemes_store.append (out schemes_iter);
            schemes_store.set (schemes_iter, 0, scheme.id, 1, scheme.name);

            if (scheme.id == prefs.editor_scheme) {
                scheme_box.active = i;
            }

            i++;
        }

        var scheme_label = new Gtk.Label.with_mnemonic (_("Editor _theme:"));
        scheme_label.mnemonic_widget = scheme_box;
        scheme_label.halign = Gtk.Align.END;

        layout.attach (scheme_label, 0, row, 1, 1);
        layout.attach_next_to (scheme_box, scheme_label, Gtk.PositionType.RIGHT, 1, 1);
        row++;

        // Autosave
        autosave_btn = new Gtk.CheckButton.with_label (_("Save automatically every"));
        autosave_spin = new Gtk.SpinButton.with_range (0, 999, 1);
        autosave_btn.set_active (prefs.autosave_interval != 0);

        if (prefs.autosave_interval != 0) {
            autosave_spin.set_value (prefs.autosave_interval);
        } else {
            autosave_spin.set_value (10);
        }

        // Stylesheet
        stylesheet_store = new Gtk.ListStore (2, typeof (string), typeof (int));
        Gtk.TreeIter iter;

        stylesheet_store.append (out iter);
        stylesheet_store.set (iter, 0, _("None"), 1, StylesheetState.NONE);

        stylesheet_store.append (out iter);
        stylesheet_store.set (iter, 0, _("Default"), 1, StylesheetState.DEFAULT);

        stylesheet_store.append (out iter);
        stylesheet_store.set (iter, 0, _("Custom"), 1, StylesheetState.CUSTOM);

        stylesheet_box = new Gtk.ComboBox.with_model (stylesheet_store);

        var text_renderer = new Gtk.CellRendererText ();
        stylesheet_box.pack_start (text_renderer, true);
        stylesheet_box.add_attribute (text_renderer, "text", 0);
        stylesheet_box.halign = Gtk.Align.START;

        if (!prefs.render_stylesheet) {
            stylesheet_box.active = 0;
        } else if (prefs.render_stylesheet_uri == "") {
            stylesheet_box.active = 1;
        } else {
            stylesheet_box.active = 2;
        }

        var stylesheet_label = new Gtk.Label (_("Style Sheet"));
        stylesheet_label.halign = Gtk.Align.END;

        layout.attach (stylesheet_label, 0, row, 1, 1);
        layout.attach_next_to (stylesheet_box, stylesheet_label, Gtk.PositionType.RIGHT, 1, 1);
        row++;

        var choose_stylesheet_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        stylesheet_chooser = new Gtk.FileChooserButton (_("Choose a stylesheet"),
                                                        Gtk.FileChooserAction.OPEN);

        Gtk.FileFilter stylesheet_filter = new Gtk.FileFilter ();
        stylesheet_chooser.set_filter (stylesheet_filter);
        stylesheet_filter.add_mime_type ("text/css");
        choose_stylesheet_box.pack_start (stylesheet_chooser);

        csb_revealer = new Gtk.Revealer ();
        csb_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        csb_revealer.add (choose_stylesheet_box);
        csb_revealer.set_reveal_child (false);

        layout.attach (csb_revealer, 1, row, 1, 1);
        row++;

        var stack = new Gtk.Stack ();
        stack.add_named (layout, "main");

        this.add (stack);
        stack.show_all ();
    }

    private void setup_events () {
        font_btn.font_set.connect (() => {
            unowned string name = font_btn.get_font_name ();
            prefs.editor_font = name;
        });

        scheme_box.changed.connect(() => {
            Value box_val;
            scheme_box.get_active_iter (out schemes_iter);
            schemes_store.get_value (schemes_iter, 0, out box_val);

            var scheme_id = (string) box_val;
            prefs.editor_scheme = scheme_id;
        });

        autosave_btn.toggled.connect((b) => {
            if (autosave_btn.get_active ()) {
                prefs.autosave_interval = (int) autosave_spin.get_value ();
            } else {
                prefs.autosave_interval = 0;
            }
        });
        autosave_spin.changed.connect(() => {
            if (!autosave_btn.get_active ()) {
                return;
            }
            prefs.autosave_interval = (int) autosave_spin.get_value ();
        });

        stylesheet_box.changed.connect (() => {
            Gtk.TreeIter iter;
            stylesheet_box.get_active_iter (out iter);

            GLib.Value state_value;
            stylesheet_store.get_value (iter, 1, out state_value);
            StylesheetState state = (StylesheetState) state_value.get_int ();

            switch (state) {
            case StylesheetState.NONE:
                prefs.render_stylesheet = false;
                csb_revealer.set_reveal_child (false);
                break;

            case StylesheetState.CUSTOM:
                csb_revealer.set_reveal_child (true);
                break;

            case StylesheetState.DEFAULT:
                prefs.render_stylesheet = true;
                prefs.render_stylesheet_uri = "";
                csb_revealer.set_reveal_child (false);
                break;
            }
        });
    }

    private Gtk.SourceStyleScheme[] get_source_schemes () {
        var style_manager = Gtk.SourceStyleSchemeManager.get_default ();
        unowned string[] scheme_ids = style_manager.get_scheme_ids ();
        Gtk.SourceStyleScheme[] schemes = {};

        foreach (string id in scheme_ids) {
            schemes += style_manager.get_scheme (id);
        }
        return schemes;
    }
}