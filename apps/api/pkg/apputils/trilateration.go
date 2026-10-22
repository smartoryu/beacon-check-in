package apputils

import "math"

// Anchor is a positioned beacon with an estimated distance from the device.
type Anchor struct {
	X         float64
	Y         float64
	DistanceM float64
	Weight    float64
}

// DistanceFromRSSI converts an RSSI reading to metres using the log-distance
// path-loss model. txPower is the calibrated RSSI at 1 metre.
func DistanceFromRSSI(txPower, rssi int, pathLossExponent float64) (float64, bool) {
	if pathLossExponent <= 0 {
		pathLossExponent = 2.0
	}
	exponent := (float64(txPower) - float64(rssi)) / (10 * pathLossExponent)
	distance := math.Pow(10, exponent)
	if math.IsNaN(distance) || math.IsInf(distance, 0) || distance < 0 {
		return 0, false
	}
	return distance, true
}

// ClampDistance bounds an estimated distance to a sensible range.
func ClampDistance(distance, maxDistance float64) float64 {
	if maxDistance <= 0 {
		maxDistance = 50
	}
	if distance < 0 {
		return 0
	}
	if distance > maxDistance {
		return maxDistance
	}
	return distance
}

// Trilaterate estimates a 2D position from three or more anchors using
// weighted linear least squares. It returns accuracy as the RMS residual in
// metres. When the geometry is degenerate it falls back to a weighted centroid.
func Trilaterate(anchors []Anchor) (x, y, accuracy float64, ok bool) {
	valid := make([]Anchor, 0, len(anchors))
	for _, anchor := range anchors {
		if anchor.DistanceM > 0 && !math.IsNaN(anchor.DistanceM) && !math.IsInf(anchor.DistanceM, 0) {
			valid = append(valid, anchor)
		}
	}
	if len(valid) < 3 {
		return 0, 0, 0, false
	}

	ref := valid[0]
	var ata00, ata01, ata11, atb0, atb1 float64
	for _, anchor := range valid[1:] {
		ax := 2 * (anchor.X - ref.X)
		ay := 2 * (anchor.Y - ref.Y)
		b := ref.DistanceM*ref.DistanceM - anchor.DistanceM*anchor.DistanceM +
			anchor.X*anchor.X - ref.X*ref.X + anchor.Y*anchor.Y - ref.Y*ref.Y
		weight := anchor.Weight
		if weight <= 0 {
			weight = 1 / (anchor.DistanceM*anchor.DistanceM + 1)
		}
		ata00 += weight * ax * ax
		ata01 += weight * ax * ay
		ata11 += weight * ay * ay
		atb0 += weight * ax * b
		atb1 += weight * ay * b
	}

	det := ata00*ata11 - ata01*ata01
	if math.Abs(det) < 1e-9 {
		return WeightedCentroid(valid)
	}

	x = (atb0*ata11 - atb1*ata01) / det
	y = (ata00*atb1 - ata01*atb0) / det
	accuracy = rmsResidual(valid, x, y)
	if math.IsNaN(x) || math.IsNaN(y) || math.IsInf(x, 0) || math.IsInf(y, 0) {
		return WeightedCentroid(valid)
	}
	return x, y, accuracy, true
}

// WeightedCentroid estimates a position as a distance-weighted average. It is
// the fallback for one or two anchors and degenerate trilateration geometry.
func WeightedCentroid(anchors []Anchor) (x, y, accuracy float64, ok bool) {
	var sumW, sumX, sumY float64
	for _, anchor := range anchors {
		if anchor.DistanceM <= 0 {
			continue
		}
		weight := anchor.Weight
		if weight <= 0 {
			weight = 1 / (anchor.DistanceM*anchor.DistanceM + 1)
		}
		sumW += weight
		sumX += weight * anchor.X
		sumY += weight * anchor.Y
	}
	if sumW == 0 {
		return 0, 0, 0, false
	}
	x = sumX / sumW
	y = sumY / sumW
	return x, y, rmsResidual(anchors, x, y), true
}

func rmsResidual(anchors []Anchor, x, y float64) float64 {
	if len(anchors) == 0 {
		return 0
	}
	var sum float64
	for _, anchor := range anchors {
		if anchor.DistanceM <= 0 {
			continue
		}
		actual := math.Hypot(anchor.X-x, anchor.Y-y)
		diff := actual - anchor.DistanceM
		sum += diff * diff
	}
	return math.Sqrt(sum / float64(len(anchors)))
}
