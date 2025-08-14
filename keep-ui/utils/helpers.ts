import { twMerge } from "tailwind-merge";
import { clsx, type ClassValue } from "clsx";

export function onlyUnique(value: string, index: number, array: string[]) {
  return array.indexOf(value) === index;
}

function isValidDate(d: Date) {
  return d instanceof Date && !isNaN(d.getTime());
}

export function capitalize(string: string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

export function toDateObjectWithFallback(date: string | Date) {
  /**
   * Since we have a weak typing validation in the backend today (lastReceived is just a string),
   * we need to make sure that we have a valid date object before we can use it.
   *
   * Having invalid dates from the backend will cause the frontend to crash.
   * (new Date(invalidDate) throws an exception)
   */
  if (date instanceof Date) {
    return date;
  }

  // If the date is not a valid date, it will return a date object with the given date string
  // https://stackoverflow.com/questions/1353684/detecting-an-invalid-date-date-instance-in-javascript
  const dateObject = new Date(date);
  if (isValidDate(dateObject)) {
    return dateObject;
  }
  // If the date is not a valid date, return a date object with the current date time
  return new Date();
}

/**
 * Formats a date for use with TimeAgo component
 * Handles different date formats from the API and ensures proper timezone handling
 */
export function formatDateForTimeAgo(date: string | Date | null | undefined): string {
  if (!date) {
    return '';
  }

  let dateString: string;

  // If it's already a Date object, convert to ISO string
  if (date instanceof Date) {
    dateString = date.toISOString();
  } else if (typeof date === 'string') {
    // If it's a string but doesn't end with Z, append it
    if (!date.endsWith('Z')) {
      dateString = date + 'Z';
    } else {
      dateString = date;
    }
  } else {
    return '';
  }

  // Validate the date
  const dateObj = new Date(dateString);
  if (isNaN(dateObj.getTime())) {
    console.warn('Invalid date format:', date);
    return '';
  }

  return dateString;
}

/**
 * Test function to verify date formatting works correctly
 * This can be called from browser console for debugging
 */
export function testDateFormatting() {
  const testCases = [
    '2024-01-15T10:30:00',
    '2024-01-15T10:30:00Z',
    new Date('2024-01-15T10:30:00Z'),
    null,
    undefined,
    'invalid-date'
  ];

  console.log('Testing date formatting:');
  testCases.forEach((testCase, index) => {
    const result = formatDateForTimeAgo(testCase);
    console.log(`Test ${index + 1}:`, testCase, '→', result);
  });
}

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function areSetsEqual<T>(set1: Set<T>, set2: Set<T>): boolean {
  if (set1.size !== set2.size) {
    return false;
  }

  for (const item of set1) {
    if (!set2.has(item)) {
      return false;
    }
  }

  return true;
}
