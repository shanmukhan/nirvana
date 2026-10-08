void requirePositiveNumber(num value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Enter a finite number greater than zero.');
  }
}

void requireNonNegativeNumber(num value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Enter a finite number of zero or more.');
  }
}

void requireRating(int? value, String name, {int min = 0, int max = 10}) {
  if (value != null && (value < min || value > max)) {
    throw RangeError.range(value, min, max, name);
  }
}
