package provide dialog_audio 0.1

namespace eval ::dialog_audio:: {
    namespace export pdtk_audio_dialog
    variable referenceconfig ""
}
set ::audio_samplerate 48000
set ::audio_advance 25
set ::audio_blocksize 64
set ::audio_use_callback 0
set ::audio_can_multidevice 0

## audio devices (available and used)
# ::audio_*devlist: a list of available input devices (type:string)
# ::audio_*devices: currently used input devices (type:index)
# ::audio_*devcechannels: currently used channels per input device (type:int)
# the length of the 'currently used' lists is currently hardcoded to 4
# (to match Pd's "audio-dialog")
set ::audio_indevlist {}
set ::audio_indevices {-1 -1 -1 -1}
set ::audio_indevicechannels {0 0 0 0}
set ::audio_outdevlist {}
set ::audio_outdevices {-1 -1 -1 -1}
set ::audio_outdevicechannels {0 0 0 0}

# TODO this panel really needs some reworking, it works but the code is very
# unreadable.  The panel could look a lot better too, like using menubuttons
# instead of regular buttons with tk_popup for pulldown menus.

####################### audio dialog ##################

# turn the current configuration into a string ready to be sent to Pd
proc ::dialog_audio::config2string { } {
    return [string trim " \
        [expr $::dialog_audio::indev1 + 0] \
        [expr $::dialog_audio::indev2 + 0] \
        [expr $::dialog_audio::indev3 + 0] \
        [expr $::dialog_audio::indev4 + 0] \
        [expr $::dialog_audio::inchan1 * ( $::dialog_audio::inenable1 ? 1 : -1 ) ]\
        [expr $::dialog_audio::inchan2 * ( $::dialog_audio::inenable2 ? 1 : -1 ) ]\
        [expr $::dialog_audio::inchan3 * ( $::dialog_audio::inenable3 ? 1 : -1 ) ]\
        [expr $::dialog_audio::inchan4 * ( $::dialog_audio::inenable4 ? 1 : -1 ) ]\
        [expr $::dialog_audio::outdev1 + 0] \
        [expr $::dialog_audio::outdev2 + 0] \
        [expr $::dialog_audio::outdev3 + 0] \
        [expr $::dialog_audio::outdev4 + 0] \
        [expr $::dialog_audio::outchan1 * ( $::dialog_audio::outenable1 ? 1 : -1 ) ]\
        [expr $::dialog_audio::outchan2 * ( $::dialog_audio::outenable2 ? 1 : -1 ) ]\
        [expr $::dialog_audio::outchan3 * ( $::dialog_audio::outenable3 ? 1 : -1 ) ]\
        [expr $::dialog_audio::outchan4 * ( $::dialog_audio::outenable4 ? 1 : -1 ) ]\
        [expr $::dialog_audio::samplerate + 0] \
        [expr $::dialog_audio::advance + 0] \
        [expr $::dialog_audio::use_callback + 0] \
        [expr $::dialog_audio::blocksize] \
        "]
}

proc ::dialog_audio::apply {mytoplevel {force ""}} {
    set config [config2string]
    if { $force ne "" || $config ne $::dialog_audio::referenceconfig} {
        pdsend "pd audio-dialog ${config}"
    }
    set ::dialog_audio::referenceconfig $config
}

proc ::dialog_audio::cancel {mytoplevel} {
    pdsend "$mytoplevel cancel"
}

proc ::dialog_audio::ok {mytoplevel} {
    ::dialog_audio::apply $mytoplevel 1
    ::dialog_audio::cancel $mytoplevel
}


# check if the value has an 'unchangeable' marker (a '!'-prefix)
# returns the value (without the marker) and a boolean whether the marker was set
# e.g. '!44100' -> {44100 1}
proc ::dialog_audio::isfixed {value} {
    set fixed 0
    if { [string match "!*" ${value}] } {
        set fixed 1
    }
    list [string trimleft "${value}" "!"] $fixed
}

# enables/disables a number of widgets ('args')) based on 'state' (0/1)
proc ::dialog_audio::state2widgets {state args} {
    set s "normal"
    if { $state == 0 } {
        set s "disabled"
    }
    foreach w $args {
        $w configure -state $s
    }

}

proc ::dialog_audio::fill_frame_device {frame direction index} {
    ## side-effects:
    ## ro: ::audio_${direction}devlist
    ## rw: ::dialog_audio::${direction}dev${index}
    ##
    ## rW: ::dialog_audio::${direction}dev${index}
    ## rW: ::dialog_audio::${direction}enable${index}
    ## rW: ::dialog_audio::${direction}chan${index}
    upvar ::dialog_audio::${direction}dev${index} x
    upvar ::audio_${direction}devlist devlist
    upvar ::dialog_audio::${direction}enable${index} enabled
    set device [lindex $devlist $x]
    if { "${device}" eq "" } {set device [format "(%s)" [_ "no device" ]] }

    checkbutton $frame.x0 -variable ::dialog_audio::${direction}enable${index} \
        -text "${index}:" -anchor e \
        -command "::dialog_audio::state2widgets \$::dialog_audio::${direction}enable${index}  $frame.x1 $frame.x2"

    if { $::audio_can_multidevice <= 1 && $direction eq "out" } {
        label $frame.x1 -text [_ "(same as input device)..."]
    } else {
        menubutton $frame.x1 -indicatoron 1 -menu $frame.x1.menu \
            -relief raised -highlightthickness 1 -anchor c \
            -direction flush \
            -text $device
        menu $frame.x1.menu -tearoff 0
        set idx 0
        foreach input $devlist {
            $frame.x1.menu add radiobutton \
                -label "${input}" \
                -value ${idx} -variable ::dialog_audio::${direction}dev${index} \
                -command "$frame.x1 configure -text \"${input}\""
            incr idx
        }
    }
    label $frame.l2 -text [_ "Channels:"]
    entry $frame.x2 -textvariable ::dialog_audio::${direction}chan${index} -width 3
    pack $frame.x0 -side left
    pack $frame.x1 -side left -fill x -expand 1
    pack $frame.x2 $frame.l2 -side right


    ::dialog_audio::state2widgets $enabled $frame.x1  $frame.x2
    if { [llength $devlist] < 2 } {
        $frame.x1 configure -state disabled
    }
}
proc ::dialog_audio::fill_frame_devices {frame direction maxdevs} {
    # side effects:
    ## ro: devlist_::audio_${direction}devlist

    upvar ::audio_${direction}devlist devlist
    set numdevs [llength $devlist]
    if { $maxdevs > $numdevs } { set maxdevs $numdevs }
    for {set i 1} {$i <= $maxdevs} {incr i} {
        frame ${frame}.${i}f
        pack ${frame}.${i}f -side top -fill x
        fill_frame_device ${frame}.${i}f ${direction} ${i}
    }
}

proc ::dialog_audio::fill_frame_iodevices {mytoplevel maxdevs longform} {
    # side effects: none

    if {[winfo exists $mytoplevel]} {
        destroy $mytoplevel
    }
    frame $mytoplevel
    pack  $mytoplevel -side top -fill x -anchor n -expand 1

    set showdevs $maxdevs
    if {$longform == 0} {
        set showdevs 1
    }
    # input devices
    labelframe $mytoplevel.inputs -text [_ "Input Devices"] -padx 5 -pady 5 -borderwidth 1
    pack $mytoplevel.inputs -side top -fill x -pady 5
    ::dialog_audio::fill_frame_devices $mytoplevel.inputs in ${showdevs}

    # output devices
    labelframe $mytoplevel.outputs -text [_ "Output Devices"] -padx 5 -pady 5 -borderwidth 1
    pack $mytoplevel.outputs -side top -fill x -pady 5
    ::dialog_audio::fill_frame_devices $mytoplevel.outputs out ${showdevs}

    # If not the "long form" but if "multi" is 2, make a button to
    # restart with longform set.
    if {$longform == 0 && $maxdevs > 1} {
        frame $mytoplevel.longbutton
        pack $mytoplevel.longbutton -side right -fill x
        button $mytoplevel.longbutton.b -text [_ "Use Multiple Devices"] \
            -command  "::dialog_audio::fill_frame_iodevices $mytoplevel $maxdevs 1"
        pack $mytoplevel.longbutton.b -expand 1 -ipadx 10 -pady 5
    }
}



proc ::dialog_audio::fill_frame {mytoplevel} {
    # side-effects:
    # rW: ::dialog_audio::samplerate
    # rW: ::dialog_audio::advance
    # rW: ::dialog_audio::use_callback
    ::dialog_audio::init_devicevars

    # settings
    labelframe $mytoplevel.settings -text [_ "Settings"] -padx 5 -pady 5 -borderwidth 1
    pack $mytoplevel.settings -side top -fill x -pady 5

    frame $mytoplevel.settings.srd
    pack $mytoplevel.settings.srd -side top -fill x
    label $mytoplevel.settings.srd.sr_label -text [_ "Sample rate:"]
    entry $mytoplevel.settings.srd.sr_entry -textvariable ::dialog_audio::samplerate -width 8
    label $mytoplevel.settings.srd.d_label -text [_ "Delay (msec):"]
    entry $mytoplevel.settings.srd.d_entry -textvariable ::dialog_audio::advance -width 4
    pack $mytoplevel.settings.srd.sr_label $mytoplevel.settings.srd.sr_entry -side left
    pack $mytoplevel.settings.srd.d_entry $mytoplevel.settings.srd.d_label -side right
    frame $mytoplevel.settings.bsc
    pack $mytoplevel.settings.bsc -side top -fill x
    button $mytoplevel.settings.bsc.rate1 -text [_ "48k"] \
        -command "set ::dialog_audio::samplerate 48000"
    button $mytoplevel.settings.bsc.rate2 -text [_ "44.1k"] \
        -command "set ::dialog_audio::samplerate 44100"
    button $mytoplevel.settings.bsc.rate3 -text [_ "96k"] \
        -command "set ::dialog_audio::samplerate 96000"
    pack $mytoplevel.settings.bsc.rate1 \
        $mytoplevel.settings.bsc.rate2 \
        $mytoplevel.settings.bsc.rate3 \
         -side left

    label $mytoplevel.settings.bsc.bs_label -text [_ "Block size:"]
    set blocksizes {64 128 256 512 1024 2048}
    set bsmenu \
        [eval tk_optionMenu $mytoplevel.settings.bsc.bs_popup ::dialog_audio::blocksize $blocksizes]
    pack $mytoplevel.settings.bsc.bs_popup -side right
    pack $mytoplevel.settings.bsc.bs_label -side right -padx {0 10}


    frame $mytoplevel.settings.callback
    pack $mytoplevel.settings.callback -side bottom -fill x
    checkbutton $mytoplevel.settings.callback.c_button -variable ::dialog_audio::use_callback \
        -text [_ "Use callbacks"]
    pack $mytoplevel.settings.callback.c_button


    if {$::dialog_audio::isfixed_samplerate} {
        $mytoplevel.settings.srd.sr_entry config -state "disabled"
        $mytoplevel.settings.bsc.rate1 config -state "disabled"
        $mytoplevel.settings.bsc.rate2 config -state "disabled"
        $mytoplevel.settings.bsc.rate3 config -state "disabled"
    }

    if {$::dialog_audio::isfixed_advance} {
        $mytoplevel.settings.srd.d_entry config -state "disabled"
    }

    if {$::dialog_audio::isfixed_blocksize} {
        $mytoplevel.settings.bsc.bs_popup config -state "disabled"
    }

    if {$::dialog_audio::isfixed_use_callback} {
        $mytoplevel.settings.callback.c_button config -state "disabled"
    }


    # FIXXME: longform+multi -> 4 else 1
    if { $::audio_can_multidevice <= 1 } {
        set maxdevs 1
    } else {
        set maxdevs 4
    }
    # FIXXME: use longform by default if...
    set longform 0

    frame $mytoplevel.iodevf
    pack  $mytoplevel.iodevf -side top -anchor n -fill x -expand 1
    ::dialog_audio::fill_frame_iodevices $mytoplevel.iodevf.contentf $maxdevs $longform
}


proc ::dialog_audio::init_devicevars {} {
    foreach direction {in out} {
        # input vars
        upvar ::audio_${direction}devices devices
        upvar ::audio_${direction}devicechannels channels
        for {set i 1} {$i <= 4} {incr i} {
            # output vars
            upvar ::dialog_audio::${direction}dev${i} dev
            upvar ::dialog_audio::${direction}chan${i} chan
            upvar ::dialog_audio::${direction}enable${i} enabled

            set c [lindex $channels ${i}-1]
            set dev [lindex $devices ${i}-1]
            set chan [expr ( $c > 0 ? $c : -$c ) ]
            set enabled [expr $c > 0 ]
        }
    }
    # resolve immutable variables (prepended with '!')
    foreach v {samplerate blocksize advance use_callback} {
        upvar ::dialog_audio::${v} var
        upvar ::dialog_audio::isfixed_${v} fixed
        upvar ::audio_${v} invar
        foreach {var fixed} [isfixed $invar] {}
    }
    set ::dialog_audio::referenceconfig [config2string]

}

# start a dialog window to select audio devices and settings.  "multi"
# is 0 if only one device is allowed; 1 if one apiece may be specified for
# input and output; and 2 if we can select multiple devices.  "longform"
# (which only makes sense if "multi" is 2) asks us to make controls for
# opening several devices; if not, we get an extra button to turn longform
# on and restart the dialog.
#
# sr, advance, callback and blocksize can be prefixed with '!', indicating
# that these values must not be changed by the GUI
proc ::dialog_audio::pdtk_audio_dialog {mytoplevel \
        indev1 indev2 indev3 indev4 \
        inchan1 inchan2 inchan3 inchan4 \
        outdev1 outdev2 outdev3 outdev4 \
        outchan1 outchan2 outchan3 outchan4 \
        sr advance multi callback \
        longform blocksize} {

    # initialize variables
    set ::audio_indevices [list $indev1 $indev2 $indev3 $indev4]
    set ::audio_indevicechannels  [list $inchan1 $inchan2 $inchan3 $inchan4]
    set ::audio_outdevices [list $outdev1 $outdev2 $outdev3 $outdev4]
    set ::audio_outdevicechannels  [list $outchan1 $outchan2 $outchan3 $outchan4]
    set ::audio_samplerate $sr
    set ::audio_advance $advance
    set ::audio_blocksize $blocksize
    set ::audio_use_callback $callback
    set ::audio_can_multidevice $multi

    # create a dialog window
    toplevel $mytoplevel -class DialogWindow
    wm withdraw $mytoplevel
    wm title $mytoplevel [_ "Audio Settings"]
    wm group $mytoplevel .
    wm resizable $mytoplevel 0 0
    wm transient $mytoplevel
    wm minsize $mytoplevel 380 320
    $mytoplevel configure -menu $::dialog_menubar
    $mytoplevel configure -padx 10 -pady 5
    ::pd_bindings::dialog_bindings $mytoplevel "audio"

    # add the preference widgets to the dialog
    ::dialog_audio::fill_frame $mytoplevel

    # save all settings button
    button $mytoplevel.saveall -text [_ "Save All Settings"] \
        -command "::dialog_audio::apply $mytoplevel 1; pdsend \"pd save-preferences\""
    pack $mytoplevel.saveall -side top -expand 1 -ipadx 10 -pady 5

    # buttons
    frame $mytoplevel.buttonframe
    pack $mytoplevel.buttonframe -side top -after $mytoplevel.saveall -pady 2m
    button $mytoplevel.buttonframe.cancel -text [_ "Cancel"] \
        -command "::dialog_audio::cancel $mytoplevel"
    pack $mytoplevel.buttonframe.cancel -side left -expand 1 -fill x -padx 15 -ipadx 10
    button $mytoplevel.buttonframe.apply -text [_ "Apply"] \
        -command "::dialog_audio::apply $mytoplevel 1"
    pack $mytoplevel.buttonframe.apply -side left -expand 1 -fill x -padx 15 -ipadx 10
    button $mytoplevel.buttonframe.ok -text [_ "OK"] \
        -command "::dialog_audio::ok $mytoplevel" -default active
    pack $mytoplevel.buttonframe.ok -side left -expand 1 -fill x -padx 15 -ipadx 10

    # for focus handling on OSX
    if {$::windowingsystem eq "aqua"} {

        # call apply on Return in entry boxes that are in focus & rebind Return to ok button
        bind $mytoplevel.settings.srd.sr_entry <KeyPress-Return> "::dialog_audio::rebind_return $mytoplevel"
        bind $mytoplevel.settings.srd.d_entry <KeyPress-Return> "::dialog_audio::rebind_return $mytoplevel"
        bind $mytoplevel.outputs.out1f.x2 <KeyPress-Return> "::dialog_audio::rebind_return $mytoplevel"

        # unbind Return from ok button when an entry takes focus
        $mytoplevel.settings.srd.sr_entry config -validate focusin -vcmd "::dialog_audio::unbind_return $mytoplevel"
        $mytoplevel.settings.srd.d_entry config -validate focusin -vcmd "::dialog_audio::unbind_return $mytoplevel"
        $mytoplevel.outputs.out1f.x2 config -validate focusin -vcmd "::dialog_audio::unbind_return $mytoplevel"

        # remove cancel button from focus list since it's not activated on Return
        $mytoplevel.buttonframe.cancel config -takefocus 0

        # show active focus on multiple device button
        if {[winfo exists $mytoplevel.longbutton.b]} {
            bind $mytoplevel.longbutton.b <KeyPress-Return> "$mytoplevel.longbutton.b invoke"
            bind $mytoplevel.longbutton.b <FocusIn> "::dialog_audio::unbind_return $mytoplevel; $mytoplevel.longbutton.b config -default active"
            bind $mytoplevel.longbutton.b <FocusOut> "::dialog_audio::rebind_return $mytoplevel; $mytoplevel.longbutton.b config -default normal"
        }

        # show active focus on save settings button
        bind $mytoplevel.saveall <KeyPress-Return> "$mytoplevel.saveall invoke"
        bind $mytoplevel.saveall <FocusIn> "::dialog_audio::unbind_return $mytoplevel; $mytoplevel.saveall config -default active"
        bind $mytoplevel.saveall <FocusOut> "::dialog_audio::rebind_return $mytoplevel; $mytoplevel.saveall config -default normal"

        # show active focus on the ok button as it *is* activated on Return
        $mytoplevel.buttonframe.ok config -default normal
        bind $mytoplevel.buttonframe.ok <FocusIn> "$mytoplevel.buttonframe.ok config -default active"
        bind $mytoplevel.buttonframe.ok <FocusOut> "$mytoplevel.buttonframe.ok config -default normal"

        # since we show the active focus, disable the highlight outline
        if {[winfo exists $mytoplevel.longbutton.b]} {
            $mytoplevel.longbutton.b config -highlightthickness 0
        }
        $mytoplevel.saveall config -highlightthickness 0
        $mytoplevel.buttonframe.ok config -highlightthickness 0
        $mytoplevel.buttonframe.cancel config -highlightthickness 0
    }

    # set min size based on widget sizing & pos over pdwindow
    wm minsize $mytoplevel [winfo reqwidth $mytoplevel] [winfo reqheight $mytoplevel]
    position_over_window $mytoplevel .pdwindow
    raise $mytoplevel
}

# for focus handling on OSX
proc ::dialog_audio::rebind_return {mytoplevel} {
    bind $mytoplevel <KeyPress-Return> "::dialog_audio::ok $mytoplevel"
    focus $mytoplevel.buttonframe.ok
    return 0
}

# for focus handling on OSX
proc ::dialog_audio::unbind_return {mytoplevel} {
    bind $mytoplevel <KeyPress-Return> break
    return 1
}
