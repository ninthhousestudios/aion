transparency - global and per card (per card my require waiting until interaction model
is refined and implemented)
background switiching

color coding for cards - not the whole card, just a status strip at top

light mode/dark mode/immersive mode switching - but these should actually be presets
which leverage the overall power of the theme system

display
    outer planets
    names vs. glyphs for planets and signs
    sign names - right now drishti returns a sign name and aion renderers it, but really
arrow/drishti shouldnt know anything about sign names. arrow thinks in terms of sign
numbers, 1-12, and what these are is deteremined by the combination of system and Circle
so sign names should live in aion -- this is not actually astrological knowledge. it
just means that aion renderers sign 1 with a certain name/glyph. this means if someone
is using tropical and Circle.aditya, they can choose for sign 1 to be dhata, or for sign
1 to aries; if using tropical and Circle.zodiac, the standard would be sign 1 is aries,
but they could also choose sign 1 is dhata. likewise, some people may want adityas in a
different order, so this would allow them to do that; though of course sign 8 will
always be ruled by mars, a water, fixed, etc. which is information encoded in arrow --
the name itself is not important. (nakshatras names can stay hardcoded as i am not aware
of anyone who disagrees about these)
    these should be configurable as a global setting which is the default, but also be
changeable by card.

need to make a way of changing these options. i see some of them are in the code, but
there is on way to actually change them when running aion.
