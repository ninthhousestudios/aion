update to the interaction model which we need to brainstorm and refine

i think we didnt design it completely because i wasnt sure what i really wanted, just
had a vague idea. but after seeing and working with aion i have a better idea of what i
want.

currently the model is driven by right-click -> context menu. this stays.
one important difference is that we need to differentiate between card and canvas.
right now, right-click can open a chart or a data table. but that data table requires
you to choose a chart from the file picker. the idea is that if you have chart
Expression open, e.g., a chart renderer, if you right-click on that card, then the
context menu options are scoped to that card. so if you choose data table, it just opens
the data table for the Chart and that Expression. likewise when we add dashas. you want
the dashas for a Chart/Expression you have open, right-click on that Chart/Expression
and choose dashas. so then the canvas context menu will open a chart and do other global
type things.

tasks aion/13 and aion/24 relate to this. it may mean basically this, but i would like to implement
this sooner rather than later, because i want to expose all of the calculation options
that arrow has available so i can test them all and make sure they work.
aion/13 imagines the Expression ui on the card itself, but it makes more sense to me to
do the context menu. though the card will have a status bar with color as per aion/14,
so it could also be a dropdown from the status bar.
