
const express = require('express');
const router = express.Router();
const { eq } = require('drizzle-orm');
const fs = require('fs/promises');
const path = require('path');

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { profiles } = require('../db/schema');

const EOTC_API = 'https://eotcdev-api.natinael-96.workers.dev';
const AZAN_API = 'https://azan.quran.et/v1';
const ALADHAN_API = 'https://api.aladhan.com/v1';

const TIME_ZONE = 'Africa/Addis_Ababa';
const DEFAULT_LATITUDE = 9.005401;
const DEFAULT_LONGITUDE = 38.769362;
const ISLAMIC_METHOD = 3;

const CACHE_DIR = path.join(__dirname, '..', '..', 'cache', 'fasting');

const MONTH_NAMES = [
  'January', 'February', 'March', 'April',
  'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

// Prevent simultaneous requests from generating the same annual cache.
const cacheGenerationPromises = new Map();

// ============================================================
// DATE HELPERS
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

function parseDateParts(value) {
  if (typeof value !== 'string') {
    throw new Error('Expected a YYYY-MM-DD date string.');
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);

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
// ORTHODOX FASTING DATA
// ============================================================

async function fetchOrthodoxMonth(year, month) {
  const start = formatDate(year, month, 1);
  const end = formatDate(year, month, getMonthDays(year, month));

  const url =
    `${EOTC_API}/v1/calendar/range` +
    `?start=${start}&end=${end}`;

  const result = await fetchJson(url);

  if (!Array.isArray(result.days)) {
    throw new Error('Orthodox API did not return a days array.');
  }

  return result.days;
}

function getOrthodoxDate(apiDay) {
  const value =
    apiDay?.gregorian?.date ??
    apiDay?.gregorian ??
    apiDay?.date;

  return typeof value === 'string' ? value : value?.date ?? null;
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

  const fastingPeriods = periods.map((period) => ({
    name: period.english || period.name || 'Orthodox fast',
    nameAmharic: period.amharic || null,
  }));

  if (isFasting && fastingPeriods.length === 0 && weeklyName) {
    fastingPeriods.push({
      name: weeklyName,
      nameAmharic: weekday === 3 ? 'ረቡዕ ጾም' : 'ዓርብ ጾም',
    });
  }

  return {
    date: dateString,
    religion: 'orthodox',
    isFasting,
    title: isFasting
      ? fastingPeriods.map((p) => p.name).join(', ') ||
        weeklyName ||
        'Orthodox Fast'
      : 'Non-Fasting Day',
    titleAmharic: fastingPeriods
      .map((p) => p.nameAmharic)
      .filter(Boolean)
      .join(', ') || null,
    reason: fasting.reason ||
      (isFasting ? 'Orthodox fasting day.' : 'Not a fasting day.'),
    fastingPeriods,
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

  return {
    date: dateString,
    religion: 'orthodox',
    isFasting,
    title: isWednesday
      ? 'Wednesday Fast (ረቡዕ ጾም)'
      : isFriday
        ? 'Friday Fast (ዓርብ ጾም)'
        : 'Non-Fasting Day',
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
// ISLAMIC FASTING DATA
// ============================================================

function extractAzanDays(response) {
  const data = response?.data;

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.days)) return data.days;
  if (Array.isArray(data?.results)) return data.results;
  if (Array.isArray(data?.calendar)) return data.calendar;

  throw new Error('Unexpected Azan monthly response.');
}

function getLocalPrayerTime(day, prayerName) {
  const times = day?.times || day?.prayerTimes || day?.timings || {};
  const key = Object.keys(times).find(
    (item) => item.toLowerCase() === prayerName.toLowerCase()
  );

  if (!key) return null;

  const value = times[key];

  if (typeof value === 'string') return value;

  return value?.local || value?.time || value?.formatted || null;
}

function getDayDate(day) {
  const value = day?.date?.gregorian || day?.date || day?.gregorian || null;

  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }

  if (typeof value?.date === 'string') return value.date;

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
  const indexed = new Map();

  for (const day of extractAzanDays(response)) {
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
    throw new Error('Unexpected AlAdhan Hijri calendar response.');
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
// USER PROFILE
// ============================================================

async function getUserFastingPractice(userId) {
  const result = await db
    .select()
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);

  const profile = result[0] || {};
  const value = String(profile.fastingPractice || 'orthodox')
    .trim()
    .toLowerCase();

  if (['islam', 'islamic', 'muslim', 'ramadan'].includes(value)) {
    return 'islam';
  }

  if (
    ['both', 'all', 'orthodox_and_islam', 'orthodox and islam']
      .includes(value)
  ) {
    return 'both';
  }

  return 'orthodox';
}

// ============================================================
// YEARLY JSON CACHE
// ============================================================

function getCacheFile(year) {
  return path.join(CACHE_DIR, `fasting-calendar-${year}.json`);
}

async function readYearCache(year) {
  try {
    const content = await fs.readFile(getCacheFile(year), 'utf8');
    const cache = JSON.parse(content);

    if (
      cache.year !== year ||
      !cache.months ||
      typeof cache.months !== 'object'
    ) {
      return null;
    }

    return cache;
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.error('Could not read fasting cache:', error.message);
    }

    return null;
  }
}

async function removeOldYearCaches(currentYear) {
  await fs.mkdir(CACHE_DIR, { recursive: true });

  const files = await fs.readdir(CACHE_DIR);

  for (const file of files) {
    const match = /^fasting-calendar-(\d{4})\.json$/.exec(file);

    if (match && Number(match[1]) !== currentYear) {
      await fs.unlink(path.join(CACHE_DIR, file)).catch((error) => {
        console.error(`Could not delete old cache ${file}:`, error.message);
      });
    }
  }
}

async function buildMonth(year, month, latitude, longitude) {
  const daysInMonth = getMonthDays(year, month);

  const [orthodoxResult, islamicResult] = await Promise.allSettled([
    fetchOrthodoxMonth(year, month),
    Promise.all([
      fetchIslamicPrayerMonth(year, month, latitude, longitude),
      fetchIslamicHijriMonth(year, month),
    ]),
  ]);

  const orthodoxByDate = new Map();

  if (orthodoxResult.status === 'fulfilled') {
    for (const apiDay of orthodoxResult.value) {
      const date = getOrthodoxDate(apiDay);
      if (date) orthodoxByDate.set(date, apiDay);
    }
  }

  const prayerByDate = islamicResult.status === 'fulfilled'
    ? islamicResult.value[0]
    : new Map();

  const hijriByDate = islamicResult.status === 'fulfilled'
    ? islamicResult.value[1]
    : new Map();

  const days = [];
  const events = [];
  const fastingDays = [];

  for (let number = 1; number <= daysInMonth; number++) {
    const date = formatDate(year, month, number);

    const orthodoxApiDay = orthodoxByDate.get(date);

    const orthodox = orthodoxApiDay
      ? normalizeOrthodoxDay(orthodoxApiDay, date)
      : orthodoxWeeklyFallback(date);

    const prayerDay = prayerByDate.get(date);
    const hijriInfo = hijriByDate.get(date);

    const islam = prayerDay && hijriInfo
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

    const isFasting = orthodox.isFasting || islam.isFasting;

    const day = {
      date,
      day: number,
      weekday: new Intl.DateTimeFormat('en', {
        weekday: 'long',
        timeZone: 'UTC',
      }).format(new Date(`${date}T12:00:00Z`)),
      isFasting,
      schedules: {
        orthodox,
        islam,
      },
    };

    days.push(day);

    if (isFasting) fastingDays.push(number);

    for (const schedule of [orthodox, islam]) {
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

  return {
    month,
    year,
    monthName: `${MONTH_NAMES[month - 1]} ${year}`,
    daysInMonth,
    fastingDays,
    events,
    days,
    apiStatus: {
      orthodox: orthodoxResult.status === 'fulfilled'
        ? 'available'
        : 'fallback',
      islam: islamicResult.status === 'fulfilled'
        ? 'available'
        : 'unavailable',
    },
  };
}

async function generateYearCache(year, latitude, longitude) {
  const currentYear = Number(
    parseDateParts(getTodayAddisAbaba()).year
  );

  // At a new year, remove the previous year's JSON cache.
  // This is triggered automatically by the first request after New Year.
  if (year === currentYear) {
    await removeOldYearCaches(currentYear);
  }

  console.log(`Generating fasting calendar cache for ${year}...`);

  const months = {};

  // Fetch the twelve months once, then save them together.
  // Months are processed sequentially to avoid overwhelming external APIs.
  for (let month = 1; month <= 12; month++) {
    try {
      months[String(month)] = await buildMonth(
        year,
        month,
        latitude,
        longitude
      );
    } catch (error) {
      console.error(
        `Failed to generate fasting data for ${year}-${pad2(month)}:`,
        error.message
      );

      // Preserve a usable calendar even if the APIs fail for a month.
      const days = [];
      const fastingDays = [];

      for (
        let dayNumber = 1;
        dayNumber <= getMonthDays(year, month);
        dayNumber++
      ) {
        const date = formatDate(year, month, dayNumber);
        const orthodox = orthodoxWeeklyFallback(date);

        const islam = {
          date,
          religion: 'islam',
          isFasting: false,
          title: 'Islamic data unavailable',
          titleAmharic: null,
          reason: 'Islamic data could not be loaded.',
          fastingPeriods: [],
          hijriDate: null,
          fastingStart: null,
          fastingEnd: null,
          fajr: null,
          maghrib: null,
          durationHours: null,
          durationAvailable: false,
          source: null,
          unavailable: true,
        };

        const isFasting = orthodox.isFasting;

        days.push({
          date,
          day: dayNumber,
          weekday: new Intl.DateTimeFormat('en', {
            weekday: 'long',
            timeZone: 'UTC',
          }).format(new Date(`${date}T12:00:00Z`)),
          isFasting,
          schedules: { orthodox, islam },
        });

        if (isFasting) fastingDays.push(dayNumber);
      }

      months[String(month)] = {
        month,
        year,
        monthName: `${MONTH_NAMES[month - 1]} ${year}`,
        daysInMonth: getMonthDays(year, month),
        fastingDays,
        events: [],
        days,
        apiStatus: {
          orthodox: 'fallback',
          islam: 'unavailable',
        },
      };
    }
  }

  const cache = {
    version: 1,
    year,
    timezone: TIME_ZONE,
    generatedAt: new Date().toISOString(),
    coordinates: { latitude, longitude },
    months,
  };

  await fs.mkdir(CACHE_DIR, { recursive: true });

  // Write to a temporary file first so an interrupted write cannot
  // leave a partially written JSON cache.
  const file = getCacheFile(year);
  const temporaryFile = `${file}.tmp`;

  await fs.writeFile(
    temporaryFile,
    JSON.stringify(cache),
    'utf8'
  );

  await fs.rename(temporaryFile, file);

  console.log(`Fasting calendar cache saved: ${file}`);

  return cache;
}

async function getYearCache(year, latitude, longitude) {
  const currentYear = parseDateParts(getTodayAddisAbaba()).year;

  // Only keep the current year's cache as the persistent yearly cache.
  if (year === currentYear) {
    await removeOldYearCaches(currentYear);
  }

  // Use an existing annual cache without contacting the external APIs.
  const existing = await readYearCache(year);

  if (existing) return existing;

  const key = String(year);

  if (cacheGenerationPromises.has(key)) {
    return cacheGenerationPromises.get(key);
  }

  const generation = generateYearCache(year, latitude, longitude);

  cacheGenerationPromises.set(key, generation);

  try {
    return await generation;
  } finally {
    cacheGenerationPromises.delete(key);
  }
}

// ============================================================
// REQUEST VALIDATION
// ============================================================

function validateMonthYear(req, res) {
  const today = getTodayAddisAbaba();
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
    res.status(400).json({ error: 'Invalid latitude or longitude.' });
    return null;
  }

  return { latitude, longitude };
}

function applyReligionFilter(day, religion) {
  const schedules = {};

  if (religion === 'orthodox' || religion === 'both') {
    schedules.orthodox = day.schedules.orthodox;
  }

  if (religion === 'islam' || religion === 'both') {
    schedules.islam = day.schedules.islam;
  }

  const activeSchedules = Object.values(schedules);

  return {
    ...day,
    isFasting: activeSchedules.some(
      (schedule) => schedule?.isFasting === true
    ),
    schedules,
  };
}

function getPracticeFromQuery(req, practice) {
  const religion = String(req.query.religion || practice).toLowerCase();

  if (!['orthodox', 'islam', 'both'].includes(religion)) {
    return null;
  }

  return religion;
}

// ============================================================
// GET /api/v1/fasting/today
// ============================================================

router.get('/today', authenticateToken, async (req, res) => {
  try {
    const today = getTodayAddisAbaba();
    const { year, month } = parseDateParts(today);

    const practice = await getUserFastingPractice(req.user.id);

    const cache = await getYearCache(
      year,
      DEFAULT_LATITUDE,
      DEFAULT_LONGITUDE
    );

    const monthData = cache.months[String(month)];

    if (!monthData) {
      throw new Error('The cached calendar for this month is missing.');
    }

    const rawDay = monthData.days.find((day) => day.date === today);

    if (!rawDay) {
      throw new Error(`Today's date ${today} is missing from the cache.`);
    }

    const day = applyReligionFilter(rawDay, practice);

    let activeFast;

    if (practice === 'islam') {
      activeFast = day.schedules.islam;
    } else if (practice === 'orthodox') {
      activeFast = day.schedules.orthodox;
    } else {
      activeFast = {
        date: today,
        religion: 'both',
        isFasting: day.isFasting,
        title: Object.values(day.schedules)
          .filter((schedule) => schedule?.isFasting)
          .map((schedule) => schedule.title)
          .join(', ') || 'Non-Fasting Day',
        schedules: day.schedules,
      };
    }

    return res.status(200).json({
      success: true,
      date: today,
      timezone: TIME_ZONE,
      fastingPractice: practice,
      isFasting: activeFast?.isFasting ?? false,
      activeFast,
      schedules: day.schedules,
      apiStatus: monthData.apiStatus,
      cache: {
        year: cache.year,
        generatedAt: cache.generatedAt,
        cached: true,
      },
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
// Optional: religion=orthodox | islam | both
// ============================================================

router.get('/calendar', authenticateToken, async (req, res) => {
  try {
    const selected = validateMonthYear(req, res);
    if (!selected) return;

    const { month, year, today } = selected;

    const coords = validateCoordinates(req, res);
    if (!coords) return;

    const practice = await getUserFastingPractice(req.user.id);
    const religion = getPracticeFromQuery(req, practice);

    if (!religion) {
      return res.status(400).json({
        error: 'religion must be orthodox, islam, or both.',
      });
    }

    const cache = await getYearCache(
      year,
      coords.latitude,
      coords.longitude
    );

    const monthData = cache.months[String(month)];

    if (!monthData) {
      throw new Error('The requested month is missing from the cache.');
    }

    const days = monthData.days.map((day) => ({
      ...applyReligionFilter(day, religion),
      isToday: day.date === today,
    }));

    const events = [];

    for (const day of days) {
      for (const schedule of Object.values(day.schedules)) {
        if (schedule?.isFasting) {
          events.push({
            date: day.date,
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

    const fastingDays = days
      .filter((day) => day.isFasting)
      .map((day) => day.day);

    return res.status(200).json({
      success: true,
      month,
      year,
      monthName: monthData.monthName,
      timezone: TIME_ZONE,
      religion,
      fastingPractice: practice,
      currentDate: today,
      currentSelectedDay:
        year === parseDateParts(today).year &&
        month === parseDateParts(today).month
          ? parseDateParts(today).day
          : 1,
      daysInMonth: monthData.daysInMonth,
      fastingDays,
      events,
      days,
      apiStatus: monthData.apiStatus,
      cache: {
        year: cache.year,
        generatedAt: cache.generatedAt,
        cached: true,
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
  return res.status(200).json({
    success: true,
    reminder: {
      reminderTime: '15:00',
      enabled: false,
      note: 'This endpoint returns settings only; it does not schedule push notifications.',
    },
  });
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
