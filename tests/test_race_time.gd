extends GutTest


func test_formato() -> void:
	assert_eq(RaceTime.format(0.0), "0:00.00")
	assert_eq(RaceTime.format(83.42), "1:23.42")
	assert_eq(RaceTime.format(9.5), "0:09.50")
	assert_eq(RaceTime.format(-3.0), "0:00.00")
