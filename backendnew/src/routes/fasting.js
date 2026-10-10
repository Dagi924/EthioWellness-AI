const express = require('express');
const router = express.Router();
const { eq } = require('drizzle-orm');

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { profiles } = require('../db/schema');

const EOTC_API =
  'https://eotcdev-api.natinael-96.workers.dev';

const AZAN_API = 'https://azan.quran.et/v1';
const ALADHAN_API = 'https://api.aladhan.com/v1';

const TIME_ZONE = 'Africa/Addis_Ababa';

const DEFAULT_LATITUDE = 9.005401;
const DEFAULT_LONGITUDE = 38.769362;

const ISLAMIC_METHOD = 3;

const MONTH_NAMES = [
  'January', 'February', 'March', 'April',
  'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

// ============================================================
// GENERAL HELPERS
// ============================================================

function pad2(value) {
  return String(value).padStart(2, '0');
}

function formatDate(year, month, day) {
  return `${year}-${pad2(month)}-${pad2(day)}`;
}

function getTodayAddisAbaba() {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());

  const values = Object.fromEntries(
    parts.map(({ type, value }) => [type, value])
  );

  return formatDate(
    Number(values.year),
    Number(values.month),
    Number(values.day)
  );
}

function normalizeDateString(value) {
  if (value instanceof Date) {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: TIME_ZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(value);

    const values = Object.fromEntries(
      parts.map(({ type, value }) => [type, value])
    );

    return formatDate(
      Number(values.year),
      Number(values.month),
      Number(values.day)
    );
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();

    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      parseDateParts(trimmed);
      return trimmed;
    }

    const parsed = new Date(trimmed);

    if (!Number.isNaN(parsed.getTime())) {
      return normalizeDateString(parsed);
    }
  }

  throw new Error('Invalid date value. Expected a Date or YYYY-MM-DD string.');
}

function parseDateParts(dateString) {
  if (typeof dateString !== 'string') {
    throw new Error('Invalid date. Expected YYYY-MM-DD string.');
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateString);

  if (!match) {
    throw new Error('Invalid date. Expected YYYY-MM-DD.');
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);

  const check = new Date(Date.UTC(year, month - 1, day));

  if (
    check.getUTCFullYear() !== year ||
    check.getUTCMonth() !== month - 1 ||
    check.getUTCDate() !== day
  ) {
    throw new Error('Invalid calendar date.');
  }

  return { year, month, day };
}

function getMonthDays(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function getWeekday(dateString) {
  const { year, month, day } = parseDateParts(dateString);

  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

function parseTimeToMinutes(value) {
  if (typeof value !== 'string') return null;

  const match = value.trim().match(
    /^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$/i
  );

  if (!match) return null;

  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const meridiem = match[3]?.toUpperCase();

  if (minutes > 59 || hours > 23) return null;

  if (meridiem) {
    if (hours < 1 || hours > 12) return null;

    if (meridiem === 'AM' && hours === 12) hours = 0;
    if (meridiem === 'PM' && hours !== 12) hours += 12;
  }

  return hours * 60 + minutes;
}

function calculateDurationHours(startTime, endTime) {
  const start = parseTimeToMinutes(startTime);
  const end = parseTimeToMinutes(endTime);

  if (start === null || end === null) return null;

  let duration = end - start;

  if (duration < 0) duration += 24 * 60;

  return Number((duration / 60).toFixed(2));
}

function safeString(value, fallback = null) {
  if (value === null || value === undefined) return fallback;

  const result = String(value).trim();
  return result || fallback;
}

// ============================================================
// EXTERNAL API HELPER
// ============================================================

async function fetchJson(url, timeoutMs = 12000) {
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      'User-Agent': 'EthioWellness-AI/1.0',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    throw new Error(
      `External API returned HTTP ${response.status}: ${url}`
    );
  }

  return response.json();
}

// ============================================================
// ORTHODOX FASTING API
// ============================================================

async function fetchOrthodoxMonth(year, month) {
  const start = formatDate(year, month, 1);
  const end = formatDate(year, month, getMonthDays(year, month));

  const url =
    `${EOTC_API}/v1/calendar/range` +
    `?start=${start}&end=${end}`;

  const result = await fetchJson(url);

  if (!Array.isArray(result.days)) {
    throw new Error(
      'Unexpected Orthodox calendar API response: days array missing'
    );
  }

  return result.days;
}

function normalizeOrthodoxDay(apiDay, dateString) {
  const fasting = apiDay.fasting || {};
  const periods = Array.isArray(fasting.periods)
    ? fasting.periods
    : [];

  const isFasting = fasting.isFasting === true;
  const weekday = getWeekday(dateString);

  let weeklyName = null;

  if (weekday === 3) {
    weeklyName = 'Wednesday Fast (ረቡዕ ጾም)';
  } else if (weekday === 5) {
    weeklyName = 'Friday Fast (ዓርብ ጾም)';
  }

  const periodNames = periods.map((period) => ({
    name: period.english || period.name || 'Orthodox fast',
    nameAmharic: period.amharic || null,
  }));

  if (isFasting && periodNames.length === 0 && weeklyName) {
    periodNames.push({
      name: weeklyName,
      nameAmharic: weekday === 3 ? 'ረቡዕ ጾም' : 'ዓርብ ጾም',
    });
  }

  return {
    date: dateString,
    religion: 'orthodox',
    isFasting,
    title: isFasting
      ? periodNames.map((period) => period.name).join(', ') ||
        weeklyName ||
        'Orthodox Fast'
      : 'Non-Fasting Day',
    titleAmharic: periodNames
      .map((period) => period.nameAmharic)
      .filter(Boolean)
      .join(', ') || null,
    reason: fasting.reason || (
      isFasting ? 'Orthodox fasting day.' : 'Not a fasting day.'
    ),
    fastingPeriods: periodNames,
    ethiopianDate: apiDay.ethiopic || null,
    weekday: apiDay.weekday || null,
    fastingStart: null,
    fastingEnd: null,
    durationHours: null,
    durationAvailable: false,
    source: 'EOTCDev API',
  };
}

function orthodoxWeeklyFallback(dateString) {
  const weekday = getWeekday(dateString);

  const isWednesday = weekday === 3;
  const isFriday = weekday === 5;
  const isFasting = isWednesday || isFriday;

  const title = isWednesday
    ? 'Wednesday Fast (ረቡዕ ጾም)'
    : isFriday
      ? 'Friday Fast (ዓርብ ጾም)'
      : 'Non-Fasting Day';

  return {
    date: dateString,
    religion: 'orthodox',
    isFasting,
    title,
    titleAmharic: isWednesday
      ? 'ረቡዕ ጾም'
      : isFriday
        ? 'ዓርብ ጾም'
        : 'የማይጾምበት ቀን',
    reason: isFasting
      ? 'Estimated from the regular Wednesday/Friday pattern. Verify with the official Orthodox calendar.'
      : 'No regular weekly fast identified. The full Orthodox calendar could not be loaded.',
    fastingPeriods: [],
    ethiopianDate: null,
    weekday: null,
    fastingStart: null,
    fastingEnd: null,
    durationHours: null,
    durationAvailable: false,
    source: 'Weekly fallback; full calendar unavailable',
    fallback: true,
  };
}

// ============================================================
// ISLAMIC API
// ============================================================

function extractAzanDays(response) {
  const data = response?.data;

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.days)) return data.days;
  if (Array.isArray(data?.results)) return data.results;
  if (Array.isArray(data?.calendar)) return data.calendar;

  throw new Error(
    'Unexpected Azan monthly response: could not find daily records'
  );
}

function getLocalPrayerTime(day, prayerName) {
  const times = day?.times || day?.prayerTimes || day?.timings || {};
  const prayer = times[prayerName.toLowerCase()];

  if (typeof prayer === 'string') return prayer;

  if (prayer && typeof prayer === 'object') {
    return prayer.local || prayer.time || prayer.formatted || null;
  }

  const matchingKey = Object.keys(times).find(
    (key) => key.toLowerCase() === prayerName.toLowerCase()
  );

  if (!matchingKey) return null;

  const value = times[matchingKey];

  if (typeof value === 'string') return value;

  return value?.local || value?.time || value?.formatted || null;
}

function getDayDate(day) {
  const value =
    day?.date?.gregorian ||
    day?.date ||
    day?.gregorian ||
    null;

  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }

  if (typeof value?.date === 'string') {
    return value.date;
  }

  if (
    typeof value?.year === 'number' &&
    typeof value?.month === 'number' &&
    typeof value?.day === 'number'
  ) {
    return formatDate(value.year, value.month, value.day);
  }

  return null;
}

async function fetchIslamicPrayerMonth(year, month, latitude, longitude) {
  const url = new URL(`${AZAN_API}/monthly`);

  url.searchParams.set('lat', String(latitude));
  url.searchParams.set('lng', String(longitude));
  url.searchParams.set('timezone', TIME_ZONE);
  url.searchParams.set('year', String(year));
  url.searchParams.set('month', String(month));

  const response = await fetchJson(url.toString());
  const days = extractAzanDays(response);

  const indexed = new Map();

  for (const day of days) {
    const date = getDayDate(day);

    if (date) indexed.set(date, day);
  }

  return indexed;
}

async function fetchIslamicHijriMonth(year, month) {
  const url =
    `${ALADHAN_API}/calendar/${year}/${month}` +
    `?latitude=${DEFAULT_LATITUDE}` +
    `&longitude=${DEFAULT_LONGITUDE}` +
    `&method=${ISLAMIC_METHOD}`;

  const response = await fetchJson(url);

  if (response.code !== 200 || !Array.isArray(response.data)) {
    throw new Error('Unexpected AlAdhan Hijri calendar response');
  }

  const indexed = new Map();

  for (const day of response.data) {
    const gregorianDate = day?.date?.gregorian?.date;
    const hijri = day?.date?.hijri;

    if (
      typeof gregorianDate === 'string' &&
      /^\d{2}-\d{2}-\d{4}$/.test(gregorianDate)
    ) {
      const [dd, mm, yyyy] = gregorianDate.split('-');
      const isoDate = `${yyyy}-${mm}-${dd}`;

      indexed.set(isoDate, {
        date: isoDate,
        day: hijri?.day || null,
        monthNumber: Number(hijri?.month?.number) || null,
        monthName: hijri?.month?.en || null,
        year: hijri?.year || null,
        designation: hijri?.designation?.abbreviated || null,
      });
    }
  }

  return indexed;
}

function normalizeIslamicDay(dateString, prayerDay, hijriInfo) {
  const fajr = getLocalPrayerTime(prayerDay, 'fajr');
  const maghrib = getLocalPrayerTime(prayerDay, 'maghrib');

  const isRamadan = hijriInfo?.monthNumber === 9;

  const durationHours = isRamadan
    ? calculateDurationHours(fajr, maghrib)
    : null;

  return {
    date: dateString,
    religion: 'islam',
    isFasting: isRamadan,
    title: isRamadan ? 'Ramadan Fast' : 'Outside Ramadan',
    titleAmharic: null,
    reason: isRamadan
      ? 'Ramadan date based on the calculated Hijri calendar. Confirm the local moon-sighting announcement.'
      : 'Not identified as a Ramadan day by the calculated Hijri calendar.',
    fastingPeriods: isRamadan
      ? [{ name: 'Ramadan', nameAmharic: null }]
      : [],
    hijriDate: hijriInfo || null,
    fastingStart: isRamadan ? fajr : null,
    fastingEnd: isRamadan ? maghrib : null,
    fajr,
    maghrib,
    durationHours,
    durationAvailable: isRamadan && durationHours !== null,
    source: 'Azan Quran.et + AlAdhan',
    fallback: false,
  };
}

// ============================================================
// USER PROFILE / PREFERENCES
// ============================================================

async function getUserFastingPractice(userId) {
  const result = await db
    .select()
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);

  const profile = result[0] || {};

  const rawPractice = String(
    profile.fastingPractice || 'orthodox'
  ).trim().toLowerCase();

  if (
    ['islam', 'islamic', 'muslim', 'ramadan'].includes(rawPractice)
  ) {
    return 'islam';
  }

  if (['both', 'all', 'orthodox_and_islam'].includes(rawPractice)) {
    return 'both';
  }

  return 'orthodox';
}

function validateMonthYear(req, res) {
  const today = normalizeDateString(getTodayAddisAbaba());
  const todayParts = parseDateParts(today);

  const month = req.query.month === undefined
    ? todayParts.month
    : Number(req.query.month);

  const year = req.query.year === undefined
    ? todayParts.year
    : Number(req.query.year);

  if (
    !Number.isInteger(month) ||
    month < 1 ||
    month > 12 ||
    !Number.isInteger(year) ||
    year < 1900 ||
    year > 2200
  ) {
    res.status(400).json({
      error: 'Invalid month or year. Use month 1-12 and a valid year.',
    });

    return null;
  }

  return { month, year, today };
}

function validateCoordinates(req, res) {
  const latitude = req.query.latitude === undefined
    ? DEFAULT_LATITUDE
    : Number(req.query.latitude);

  const longitude = req.query.longitude === undefined
    ? DEFAULT_LONGITUDE
    : Number(req.query.longitude);

  if (
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    res.status(400).json({
      error: 'Invalid latitude or longitude.',
    });

    return null;
  }

  return { latitude, longitude };
}

// ============================================================
// GET /api/v1/fasting/today
// ============================================================

router.get('/today', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const today = normalizeDateString(getTodayAddisAbaba());
    const practice = await getUserFastingPractice(userId);

    const { year, month } = parseDateParts(today);

    const [orthodoxResult, islamicResult] = await Promise.allSettled([
      fetchOrthodoxMonth(year, month),
      Promise.all([
        fetchIslamicPrayerMonth(
          year,
          month,
          DEFAULT_LATITUDE,
          DEFAULT_LONGITUDE
        ),
        fetchIslamicHijriMonth(year, month),
      ]),
    ]);

    let orthodox = null;
    let islamic = null;

    if (orthodoxResult.status === 'fulfilled') {
      const match = orthodoxResult.value.find((day) => {
        const value =
          day?.gregorian?.date ||
          day?.gregorian ||
          day?.date;

        const date = typeof value === 'string'
          ? value
          : value?.date;

        return date === today;
      });

      if (match) {
        orthodox = normalizeOrthodoxDay(match, today);
      }
    }

    if (islamicResult.status === 'fulfilled') {
      const [prayerDays, hijriDays] = islamicResult.value;

      const prayerDay = prayerDays.get(today);
      const hijriInfo = hijriDays.get(today);

      if (prayerDay && hijriInfo) {
        islamic = normalizeIslamicDay(today, prayerDay, hijriInfo);
      }
    }

    if (!orthodox) {
      orthodox = orthodoxWeeklyFallback(today);
    }

    const activeFast = practice === 'islam'
      ? islamic
      : orthodox;

    return res.status(200).json({
      success: true,
      date: today,
      timezone: TIME_ZONE,
      fastingPractice: practice,
      isFasting: activeFast?.isFasting ?? false,
      activeFast,
      schedules: {
        orthodox,
        islam: islamic,
      },
      apiStatus: {
        orthodox: orthodox.fallback ? 'fallback' : 'available',
        islam: islamic ? 'available' : 'unavailable',
      },
      message: !islamic
        ? 'Islamic calendar data is temporarily unavailable.'
        : null,
    });
  } catch (err) {
    console.error('GET FASTING TODAY ERROR:', err);

    return res.status(500).json({
      error: 'Failed to retrieve fasting status',
      details: err.message,
    });
  }
});

// ============================================================
// GET /api/v1/fasting/calendar?month=10&year=2026
//
// Optional query parameters:
// religion=orthodox | islam | both
// latitude=9.005401&longitude=38.769362
// ============================================================

router.get('/calendar', authenticateToken, async (req, res) => {
  try {
    const selected = validateMonthYear(req, res);
    if (!selected) return;

    const { month, year } = selected;
    const today = normalizeDateString(selected.today);

    const coords = validateCoordinates(req, res);
    if (!coords) return;

    const practice = await getUserFastingPractice(req.user.id);

    const religion = String(
      req.query.religion || practice
    ).toLowerCase();

    if (!['orthodox', 'islam', 'both'].includes(religion)) {
      return res.status(400).json({
        error: 'religion must be orthodox, islam, or both.',
      });
    }

    const daysInMonth = getMonthDays(year, month);
    const monthName = `${MONTH_NAMES[month - 1]} ${year}`;

    const needOrthodox = religion === 'orthodox' || religion === 'both';
    const needIslam = religion === 'islam' || religion === 'both';

    const requests = await Promise.allSettled([
      needOrthodox
        ? fetchOrthodoxMonth(year, month)
        : Promise.resolve(null),

      needIslam
        ? Promise.all([
            fetchIslamicPrayerMonth(
              year,
              month,
              coords.latitude,
              coords.longitude
            ),
            fetchIslamicHijriMonth(year, month),
          ])
        : Promise.resolve(null),
    ]);

    const orthodoxAvailable =
      needOrthodox && requests[0].status === 'fulfilled';

    const islamAvailable =
      needIslam && requests[1].status === 'fulfilled';

    const orthodoxByDate = new Map();

    if (orthodoxAvailable) {
      for (const apiDay of requests[0].value) {
        const value =
          apiDay?.gregorian?.date ||
          apiDay?.gregorian ||
          apiDay?.date;

        const date = typeof value === 'string'
          ? value
          : value?.date;

        if (date) {
          orthodoxByDate.set(date, apiDay);
        }
      }
    }

    let prayerByDate = new Map();
    let hijriByDate = new Map();

    if (islamAvailable) {
      prayerByDate = requests[1].value[0];
      hijriByDate = requests[1].value[1];
    }

    const days = [];
    const events = [];
    const fastingDays = [];

    for (let dayNumber = 1; dayNumber <= daysInMonth; dayNumber++) {
      const date = formatDate(year, month, dayNumber);
      const schedules = {};

      if (needOrthodox) {
        const apiDay = orthodoxByDate.get(date);

        schedules.orthodox = apiDay
          ? normalizeOrthodoxDay(apiDay, date)
          : orthodoxWeeklyFallback(date);
      }

      if (needIslam) {
        const prayerDay = prayerByDate.get(date);
        const hijriInfo = hijriByDate.get(date);

        schedules.islam = prayerDay && hijriInfo
          ? normalizeIslamicDay(date, prayerDay, hijriInfo)
          : {
              date,
              religion: 'islam',
              isFasting: false,
              title: 'Islamic data unavailable',
              titleAmharic: null,
              reason: 'Prayer-time or Hijri calendar data could not be loaded.',
              fastingPeriods: [],
              hijriDate: hijriInfo || null,
              fastingStart: null,
              fastingEnd: null,
              fajr: null,
              maghrib: null,
              durationHours: null,
              durationAvailable: false,
              source: null,
              unavailable: true,
            };
      }

      const activeSchedules = Object.values(schedules);
      const isFasting = activeSchedules.some(
        (schedule) => schedule.isFasting === true
      );

      const day = {
        date,
        day: dayNumber,
        weekday: new Intl.DateTimeFormat('en', {
          weekday: 'long',
          timeZone: 'UTC',
        }).format(new Date(`${date}T12:00:00Z`)),
        isToday: date === today,
        isFasting,
        schedules,
      };

      days.push(day);

      if (isFasting) {
        fastingDays.push(dayNumber);
      }

      for (const schedule of activeSchedules) {
        if (schedule.isFasting) {
          events.push({
            date,
            religion: schedule.religion,
            title: schedule.title,
            titleAmharic: schedule.titleAmharic,
            fastingStart: schedule.fastingStart,
            fastingEnd: schedule.fastingEnd,
            durationHours: schedule.durationHours,
            durationAvailable: schedule.durationAvailable,
            reason: schedule.reason,
          });
        }
      }
    }

    return res.status(200).json({
      success: true,
      month,
      year,
      monthName,
      timezone: TIME_ZONE,
      religion,
      fastingPractice: practice,
      currentDate: today,
      currentSelectedDay: Number(today.slice(8, 10)),
      daysInMonth,
      fastingDays,
      events,
      days,
      apiStatus: {
        orthodox: needOrthodox
          ? (orthodoxAvailable ? 'available' : 'fallback')
          : 'not_requested',
        islam: needIslam
          ? (islamAvailable ? 'available' : 'unavailable')
          : 'not_requested',
      },
    });
  } catch (err) {
    console.error('GET FASTING CALENDAR ERROR:', err);

    return res.status(500).json({
      error: 'Failed to retrieve fasting calendar',
      details: err.message,
    });
  }
});

// ============================================================
// GET /api/v1/fasting/reminders
// ============================================================

router.get('/reminders', authenticateToken, async (req, res) => {
  try {
    return res.status(200).json({
      success: true,
      reminder: {
        reminderTime: '15:00',
        enabled: false,
        note: 'This endpoint returns settings only; it does not schedule push notifications.',
      },
    });
  } catch (err) {
    return res.status(500).json({
      error: 'Failed to retrieve reminders',
      details: err.message,
    });
  }
});

// ============================================================
// POST /api/v1/fasting/reminders
// ============================================================

router.post('/reminders', authenticateToken, async (req, res) => {
  try {
    const { reminderTime, enabled } = req.body;

    if (
      reminderTime !== undefined &&
      (
        typeof reminderTime !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(reminderTime)
      )
    ) {
      return res.status(400).json({
        error: 'reminderTime must use HH:mm format.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Reminder settings saved for this request.',
      reminder: {
        reminderTime: reminderTime || '15:00',
        enabled: enabled === undefined ? true : Boolean(enabled),
      },
      note: 'Persist reminder settings and connect push/local notifications to schedule actual alerts.',
    });
  } catch (err) {
    console.error('POST FASTING REMINDER ERROR:', err);

    return res.status(500).json({
      error: 'Failed to save reminder settings',
      details: err.message,
    });
  }
});

module.exports = router;
