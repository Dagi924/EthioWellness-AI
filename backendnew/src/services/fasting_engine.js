const fs = require('fs/promises');
const path = require('path');
const { getRamadanDateRange } = require('./ramadan_service');

/**
 * Fasting Rules Engine
 * Computes daily fasting rules based on user profile settings
 * and liturgical calendar.
 *
 * Ramadan cache:
 * - Stores one JSON file per year.
 * - Reuses cached data instead of calling the service repeatedly.
 * - Removes outdated year caches when a new year is requested.
 */

const CACHE_DIR = path.join(__dirname, '..', 'cache', 'ramadan');

function getRamadanCachePath(year) {
  return path.join(CACHE_DIR, `ramadan-${year}.json`);
}

async function removeOldRamadanCaches(currentYear) {
  await fs.mkdir(CACHE_DIR, { recursive: true });

  const files = await fs.readdir(CACHE_DIR);

  await Promise.all(
    files
      .filter((file) => {
        const match = file.match(/^ramadan-(\d{4})\.json$/);
        return match && Number(match[1]) !== currentYear;
      })
      .map((file) =>
        fs.unlink(path.join(CACHE_DIR, file)).catch((error) => {
          if (error.code !== 'ENOENT') {
            throw error;
          }
        })
      )
  );
}

async function getCachedRamadanDateRange(year) {
  await fs.mkdir(CACHE_DIR, { recursive: true });

  // Remove cached Ramadan data belonging to other years.
  await removeOldRamadanCaches(year);

  const cachePath = getRamadanCachePath(year);

  try {
    const cachedContent = await fs.readFile(cachePath, 'utf8');
    const cachedData = JSON.parse(cachedContent);

    if (
      cachedData.year === year &&
      Object.prototype.hasOwnProperty.call(cachedData, 'data')
    ) {
      return cachedData.data;
    }
  } catch (error) {
    if (error.code !== 'ENOENT' && !(error instanceof SyntaxError)) {
      throw error;
    }
  }

  // Cache miss: call the original service once and save its result.
  const ramadanData = await getRamadanDateRange(year);

  const cacheData = {
    year,
    cachedAt: new Date().toISOString(),
    data: ramadanData,
  };

  const temporaryPath = `${cachePath}.tmp`;

  await fs.writeFile(
    temporaryPath,
    JSON.stringify(cacheData, null, 2),
    'utf8'
  );

  await fs.rename(temporaryPath, cachePath);

  return ramadanData;
}

/**
 * Computes daily fasting rules.
 *
 * Supported practices:
 * - orthodox
 * - ramadan
 * - custom / other
 */
async function calculateDailyFastingRule(
  userProfile,
  dateObj = new Date()
) {
  const practice = String(
    userProfile?.fastingPractice || 'orthodox'
  )
    .trim()
    .toLowerCase();

  // Use the local date components rather than converting to UTC.
  const dayOfWeek = dateObj.getDay();

  if (practice === 'orthodox') {
    const isWednesday = dayOfWeek === 3;
    const isFriday = dayOfWeek === 5;

    if (isWednesday || isFriday) {
      return {
        practice: 'orthodox',
        title: isWednesday ? 'Wednesday Fast' : 'Friday Fast',
        titleAmharic: isWednesday ? 'ረቡዕ ጾም' : 'አርብ ጾም',
        dayNumber: 3,
        isVeganRequired: true,
        fastingEndsTime: '3:00 PM (9 ሰዓት)',
        ruleDescription:
          'Adhering to strict plant-based guidelines. Complete exclusion of meat, dairy, eggs, and animal fats.',
        allowedTodayText: '100% Plant-Based (Tsom)',
        tips: [
          {
            title: 'Protein Focus',
            desc: 'Combine Shiro (chickpeas) with Injera (teff) for a complete amino acid profile.',
          },
          {
            title: 'B12 & Micronutrients',
            desc: 'Consider fortified plant milks or B12 supplementation during extended fasting.',
          },
        ],
      };
    }

    return {
      practice: 'orthodox',
      title: 'Non-Fasting Day',
      titleAmharic: 'የጾም ቀን አይደለም',
      isVeganRequired: false,
      fastingEndsTime: 'N/A',
      ruleDescription:
        'Standard heritage nutrition day. Balanced protein, healthy fats, and complex carbohydrates allowed.',
      allowedTodayText: 'All Heritage Foods Allowed',
      tips: [
        {
          title: 'Iron Balance',
          desc: 'Incorporate lean meats or eggs alongside vitamin C rich greens (Gomen).',
        },
      ],
    };
  }

  if (practice === 'ramadan') {
    const ramadanInfo = await getCachedRamadanDateRange(
      dateObj.getFullYear()
    );

    return {
      practice: 'ramadan',
      title: 'Ramadan Daily Fast',
      titleAmharic: 'የረመዳን ጾም',
      isVeganRequired: false,
      fastingEndsTime: 'Sunset (Iftar)',
      ruleDescription:
        'Abstain from food and water from sunrise (Suhoor) until sunset (Iftar). Focus on complex carbs during Suhoor and gentle rehydration during Iftar.',
      allowedTodayText: 'Suhoor & Iftar Optimized',
      tips: [
        {
          title: 'Suhoor Sustained Energy',
          desc: 'Consume Teff Genfo, dates, and ample water before dawn.',
        },
        {
          title: 'Iftar Gentle Recovery',
          desc: 'Break fast with water, dates, and warm Shiro or soups before heavy meals.',
        },
      ],

      // Keep the service's date-range result available to consumers.
      ramadanInfo,
    };
  }

  return {
    practice: practice || 'custom',
    title: 'Custom Intermittent Fasting',
    titleAmharic: 'መደበኛ አመጋገብ',
    isVeganRequired: false,
    fastingEndsTime: '16:8 Window',
    ruleDescription:
      'Standard daily nutrition tracking based on your custom profile goals.',
    allowedTodayText: 'Custom Targets Active',
    tips: [
      {
        title: 'Hydration Target',
        desc: 'Aim for at least 2.5L of water throughout your eating window.',
      },
    ],
  };
}

module.exports = {
  calculateDailyFastingRule,
  getCachedRamadanDateRange,
};
