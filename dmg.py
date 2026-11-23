# Impostazioni per dmgbuild: come appare la finestra del DMG. La usa crea-dmg.sh.
# Le posizioni delle icone devono combaciare con lo sfondo disegnato da sfondo-dmg.swift.
app = defines["app"]            # percorso di «IDE C.app»
sfondo = defines["sfondo"]      # sfondo.tiff (1x + 2x)

volume_name = "IDE C"
format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applicazioni": "/Applications"}
icon = app + "/Contents/Resources/AppIcon.icns"   # icona del disco montato

background = sfondo
window_rect = ((200, 140), (640, 400))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
show_icon_preview = False
icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    "IDE C.app": (180, 205),
    "Applicazioni": (460, 205),
}
