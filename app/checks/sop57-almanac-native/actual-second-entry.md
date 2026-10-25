---
title: "Why a Tilted Wheel's Hub Sits Off-Center in Its Ellipse (Ideal Pinhole Perspective)"
---
Photograph a round dinner plate from across the table, or look at a bicycle wheel standing a couple of metres away and slightly to one side. The rim comes out as an ellipse, as everyone expects. What is less expected: the plate's centre, or the wheel's hub, is **not** at the centre of that ellipse. It is displaced toward the far edge, and the near half of the rim takes up more of the picture than the far half.

**Setting up the ideal model.** Treat the eye as a pinhole at a point $O$, looking horizontally, with a vertical picture plane one unit in front of it. Put a circle of radius $r$ flat on a table, its centre a horizontal distance $d$ straight ahead and $h$ below eye level, with $d>r$ so the whole circle is in front of the eye. (If part of the circle were level with or behind the eye, the picture would be a parabola or hyperbola branch instead; this entry stays with the ellipse case.) Lens distortion and the curvature of a real retina are ignored; what follows is about the ideal projected image.

The nearest rim point is at depth $d-r$, the farthest at $d+r$, and the centre at $d$. A point at depth $z$ on the table appears at picture height $-h/z$. So the near half of the circle, from the centre to the near rim, occupies a picture height of

$$\frac{h}{d-r}-\frac{h}{d}=\frac{hr}{d(d-r)},$$

while the far half, from the centre to the far rim, occupies

$$\frac{h}{d}-\frac{h}{d+r}=\frac{hr}{d(d+r)}.$$

Their ratio is

$$\frac{\text{near half}}{\text{far half}}=\frac{d+r}{d-r},$$

which does not depend on $h$ at all. For a plate of radius $12\,\text{cm}$ whose centre is $1\,\text{m}$ ahead, the ratio is $1.12/0.88\approx1.27$: the near half of the plate is about a quarter taller in the picture than the far half. For a bicycle wheel of radius $35\,\text{cm}$ at $2\,\text{m}$, it is $2.35/1.65\approx1.42$. The ellipse's own geometric centre is the midpoint of the near and far rim points, so it lies in the *near* half; the image of the true centre is pushed toward the far edge. The same asymmetry can be stated without any picture plane: the near half of the circle simply subtends a larger visual angle than the far half, so it survives on a curved retina too.

**Why no projection can fix this.** A perspective picture is a central projection, and central projections preserve straight lines and conics but not midpoints. The centre of a circle is the midpoint of every diameter; after projection it is still on the image of every diameter, but no longer the midpoint of any of them, except those parallel to the picture plane. In the plate example the diameter running left–right, parallel to the picture plane, does keep its midpoint at the image of the centre. Yet that chord is not the widest chord of the ellipse: a short calculation shows the ellipse is widest slightly nearer the viewer, at the rim points whose depth satisfies $z=d-r^{2}/d$. So in an honest drawing of a wheel, the horizontal spoke pair does not reach the ellipse's widest points.

**The surprising connection: the hub is the pole of the horizon.** In the geometry of the table plane, the centre of a circle has a clean projective description: it is the *pole* of the line at infinity with respect to the circle. (The polar of the centre is the line where tangents at diametrically opposite points meet, and those tangents are parallel.) Central projection sends the table's line at infinity to the horizon line of the picture, and it preserves pole–polar relationships. Therefore, in the picture, the image of the plate's centre is the pole of the horizon line with respect to the image ellipse.

This gives a ruler-only construction. Pick any point on the horizon line, draw the two tangents from it to the ellipse, and join the two points of tangency. That chord passes through the image of the centre. Do it from a second horizon point and the two chords cross exactly at the hub. In the symmetric setup above one can check it against the formula: the pole of the horizon $y=0$ with respect to the ellipse with centre $-hd/(d^{2}-r^{2})$ and vertical semi-axis $hr/(d^{2}-r^{2})$ comes out at height $-h/d$, which is precisely where the centre projects.

**What the eye does with it.** The retina receives the off-centre ellipse, yet one sees a round plate with its pattern in the middle, and a wheel with its hub where it belongs. Perceptual psychologists call this shape constancy: the visual system treats the ellipse as evidence of a tilted circle rather than as a shape in its own right, and the off-centre hub as evidence of depth rather than of a lopsided wheel. This is why beginning drawers tend to put the hub at the ellipse's centre and then find the wheel looks subtly wrong, and why a photograph of a clock face taken from an angle can look oddly "pushed" toward one side even though the camera has done nothing but follow the geometry above. The displacement of the hub is one of the quiet cues the eye reads as depth, and the pole–polar rule is the exact bookkeeping behind it.

---
### Source basis

Prepared from general knowledge and interpretation. No external source was opened or independently checked for this entry.
