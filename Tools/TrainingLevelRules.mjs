// A spell's scaling/default SpellLevel is not automatically its learning level.
export function trainingLevel({baseLevel,spellLevel,reference}) {
    const valid = n => Number.isInteger(n) && n >= 1 && n <= 60;
    if (valid(baseLevel)) {
        if (reference?.season > 0 && baseLevel === 1) {
            return {reason:'seasonal-level-one-unverified'};
        }
        return {level:baseLevel, source:reference?.season > 0 ? 'forever-relevelled-seasonal' : 'forever-base-level'};
    }
    if (baseLevel !== 0) return {reason:'invalid-base-level'};
    // Retain established quest/skill abilities (such as Feed Pet) only when an
    // independent non-seasonal class reference corroborates the non-default level.
    const documentedStarter = Number.isFinite(reference?.cost) && reference.cost >= 0;
    if (valid(spellLevel) && (spellLevel > 1 || documentedStarter) && reference && !reference.season && reference.level === spellLevel) {
        return {level:spellLevel, source:'corroborated-classic-ability'};
    }
    return {reason:reference?.season > 0 ? 'seasonal-without-forever-learning-level' : 'unverified-learning-level'};
}
