const fs = require("fs");
const path = require("path");

const FOOD_FILE = path.join(
  __dirname,
  "data",
  "ethiopian_foods.json"
);

function loadFoods() {
  if (!fs.existsSync(FOOD_FILE)) {
    throw new Error(`Food JSON file not found: ${FOOD_FILE}`);
  }

  const data = JSON.parse(fs.readFileSync(FOOD_FILE, "utf8"));

  if (!Array.isArray(data)) {
    throw new Error("Food JSON must contain an array.");
  }

  return data;
}

function normalizeText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFKC")
    .replace(/[’‘`]/g, "'")
    .replace(/[^a-z0-9\u1200-\u137f\s']/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function extractFood(query, limit = 50) {
  if (!query || !String(query).trim()) {
    return [];
  }

  const foods = loadFoods();

  // Accept multiple keywords separated by spaces or commas.
  const keywords = normalizeText(query)
    .split(/[\s,]+/)
    .filter(Boolean);

  if (keywords.length === 0) {
    return [];
  }

  const matches = foods
    .map((food) => {
      const amharicName = normalizeText(food.nameAmharic);
      const englishName = normalizeText(food.name);

      // Split the Amharic transliteration into searchable words.
      const amharicWords = amharicName.split(/\s+/).filter(Boolean);

      const matchedKeywords = keywords.filter((keyword) =>
        amharicWords.some((word) => word.includes(keyword)) ||
        amharicName.includes(keyword) ||
        englishName.includes(keyword)
      );

      return {
        food,
        matchedCount: matchedKeywords.length,
        matchedKeywords
      };
    })
    .filter((result) => result.matchedCount > 0)
    .sort((a, b) => {
      // Prefer foods matching more of the requested keywords.
      if (b.matchedCount !== a.matchedCount) {
        return b.matchedCount - a.matchedCount;
      }

      return String(a.food.nameAmharic || "").localeCompare(
        String(b.food.nameAmharic || "")
      );
    })
    .slice(0, Math.max(1, Number(limit) || 50))
    .map(({ food }) => food);

  return matches;
}

module.exports = {
  extractFood,
  loadFoods
};

// Optional command-line usage:
// node extract-food.js "sinde"
// node extract-food.js "sinde, duket"
// node extract-food.js "yaltefetege nech sinde duket"

if (require.main === module) {
  const query = process.argv.slice(2).join(" ");

  try {
    const results = extractFood(query);

    console.log(JSON.stringify(results, null, 2));
    console.log(`\nFound ${results.length} matching foods.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
