// ============================================================
// 数据模型 —— 与 apps/mobile/ChinaTextbookStudy/Models/CoreTypes.swift 及
// packages/core/src/types.ts 的 JSON 形状逐字段一致（含 snake_case 键）。
// ============================================================

export type QuestionType = 'true_false' | 'choice' | 'fill_blank' | 'calculation' | 'fill_blank_text' |
  'word_order' | 'matching' | 'word_problem';

export interface QuestionAudio {
  question?: string | null;
  options?: (string | null)[] | null;
  explanation?: string | null;
}

export interface Question {
  id: number;
  type: QuestionType;
  score: number;
  difficulty: number;
  knowledge_point: string;
  question: string;
  options: string[];
  answer: string;
  explanation: string;
  audio?: QuestionAudio | null;
}

export interface KnowledgeAudio {
  point?: string | null;
  core_concept?: string | null;
  key_formula?: string | null;
  tips?: string | null;
  common_mistakes?: (string | null)[] | null;
}

export interface KnowledgeSummary {
  point: string;
  core_concept: string;
  key_formula: string;
  common_mistakes: string[];
  tips: string;
  audio?: KnowledgeAudio | null;
}

/** 一节"小课" = 一个知识点 + 该知识点对应的题目（5-7 道） */
export interface Lesson {
  id: string;
  title: string;
  bookId: string;
  unitNumber: number;
  unitTitle: string;
  kpIndex: number;
  kpTotal: number;
  questions: Question[];
  knowledge?: KnowledgeSummary | null;
  unitLabel?: string | null;
}

export interface KnowledgePoint {
  name: string;
  description: string;
  difficulty: number;
  question_types: string[];
}

export interface Unit {
  unit_number: number;
  title: string;
  knowledge_points: KnowledgePoint[];
  examLessonId?: string | null;
  examQuestionCount?: number | null;
  label?: string | null;
}

export interface Outline {
  textbook: string;
  units: Unit[];
}

export type SubjectId = 'math' | 'chinese' | 'english' | 'science';

export interface Book {
  id: string;
  grade: number;
  semester: string;
  subject?: SubjectId | null;
  gradeName: string;
  semesterName: string;
  subjectName?: string | null;
  textbookName: string;
  fullName: string;
  schoolSystem?: string | null;
  publisherLabel?: string | null;
  sourceEdition?: string | null;
  sourcePrinting?: string | null;
  unitsCount: number;
  lessonsCount: number;
  hasPassages?: boolean | null;
  hasStories?: boolean | null;
  editionLabel?: string | null;
  supersedes?: string | null;
  supersededBy?: string | null;
  activitiesCount?: number | null;
}

export type PassageKind = 'poem' | 'ancient_poem' | 'prose' | 'story' | 'song' | 'dialogue';

export interface PassageSentence {
  text: string;
  audio?: string | null;
}

export interface Passage {
  id: string;
  bookId: string;
  unitNumber?: number | null;
  lessonNumber: number;
  title: string;
  kind: PassageKind;
  author?: string | null;
  language: string;
  sentences: PassageSentence[];
  pageHint?: number | null;
  pdfPage?: number | null;
  pageImages?: string[] | null;
  curriculumRole?: string | null;
}

export interface BookPassages {
  bookId: string;
  subject: SubjectId;
  textbook: string;
  passages: Passage[];
}

export interface StoryQuestion {
  id: number;
  type: string;
  question: string;
  options: string[];
  answer: string;
  explanation: string;
  audio?: QuestionAudio | null;
}

export interface Story {
  id: string;
  bookId: string;
  unitNumber: number;
  unitTitle: string;
  storyIndex: number;
  title: string;
  language: string;
  sentences: PassageSentence[];
  questions: StoryQuestion[];
  image?: string | null;
}

export interface BookStories {
  bookId: string;
  subject: SubjectId;
  textbook: string;
  stories: Story[];
}

export interface SiteIndex {
  books: Book[];
  generatedAt?: string | null;
  totalLessons?: number | null;
  totalQuestions?: number | null;
}

// ============================================================
// 用户进度（持久化到 filesDir/cstf/progress.json）
// ============================================================

export interface LessonResult {
  lessonId: string;
  stars: number;
  accuracy: number;
  completedAt: string;
}

export interface MistakeEntry {
  lessonId: string;
  lessonTitle?: string | null;
  question: Question;
  addedAt: string;
  box?: number | null;
  correctCount?: number | null;
  lastReviewedAt?: string | null;
  nextReviewDate?: string | null;
  graduated?: boolean | null;
}

export interface ActiveLessonSession {
  bookId: string;
  lessonId: string;
  queueIds: number[];
  solvedIds: number[];
  missedIds: number[];
  combo: number;
  maxCombo: number;
  sessionXp: number;
  startedAt: string;
  contentKey?: string | null;
}

export interface LeagueWeekResult {
  weekKey: string;
  rank: number;
  tierBefore: string;
  tierAfter: string;
  promoted: boolean;
  demoted: boolean;
  gems: number;
}

export type QuestionReportKind = 'question_wrong' | 'answer_should_count' | 'audio_issue';

export interface QuestionReport {
  lessonId: string;
  questionId: number;
  kind: QuestionReportKind;
  createdAt: string;
  userAnswer?: string | null;
  questionText?: string | null;
}

export interface UserProgress {
  xp: number;
  streak: number;
  lastActiveDate: string;
  completedLessons: Record<string, LessonResult>;
  mistakesBank: MistakeEntry[];

  hearts?: number | null;
  nextHeartAt?: number | null;
  gems?: number | null;
  todayXp?: number | null;
  lastXpDate?: string | null;
  dailyGoal?: number | null;
  claimedChests?: Record<string, boolean> | null;
  equippedMascotSkin?: string | null;
  equippedTheme?: string | null;
  equippedBackdrop?: string | null;
  streakFreezes?: number | null;
  ownedCosmetics?: string[] | null;
  lifetimeGems?: number | null;
  displayName?: string | null;
  completedReadings?: string[] | null;

  claimedQuests?: string[] | null;
  xpHistory?: Record<string, number> | null;
  dailyDate?: string | null;
  dailyLessons?: number | null;
  dailyReviews?: number | null;
  dailyReadings?: number | null;

  claimedStreakRewards?: number[] | null;
  lastDailyRewardDate?: string | null;
  lastDailyRewardStreak?: number | null;
  lastReviewHeartDate?: string | null;
  unlockedAchievements?: string[] | null;
  freezesMigrated?: boolean | null;

  activeLesson?: ActiveLessonSession | null;
  claimedAchievements?: string[] | null;
  joinedDate?: string | null;

  leagueSalt?: string | null;
  leagueTier?: string | null;
  leagueWeekKey?: string | null;
  pendingLeagueResult?: LeagueWeekResult | null;

  seenIntros?: string[] | null;
  reports?: QuestionReport[] | null;
}

// ============================================================
// 玩法 UI 域类型
// ============================================================

export type MascotMood = 'happy' | 'cheer' | 'sad' | 'think' | 'wave' | 'surprise' | 'proud' | 'embarrassed';
export type MascotReaction = 'correct' | 'wrong' | 'levelup';

export interface PathLessonMeta {
  id: string;
  title: string;
  unitNumber: number;
  unitTitle: string;
  kpIndex: number;
  kpTotal: number;
  questionCount: number;
  unitLabel?: string | null;
}

export type LessonStatus = 'completed' | 'current' | 'locked';

/** Result of committing a finished lesson to the store. */
export class LessonOutcome {
  xpGained: number = 0;
  stars: number = 1;
  streakBefore: number = 0;
  streakAfter: number = 0;
  dailyGoalReachedNow: boolean = false;
  gemsGained: number = 0;
  newAchievementIds: string[] = [];
  milestoneGems: number = 0;
  weekendDoubled: boolean = false;
  freezesConsumed: number = 0;
  examDoubled: boolean = false;

  get streakIncreased(): boolean {
    return this.streakAfter > this.streakBefore;
  }
}

/** Snapshot pushed onto the navigation stack after a lesson finishes. */
export class LessonRunResult {
  bookId: string;
  lessonId: string;
  lessonTitle: string;
  questionCount: number;
  correctCount: number;
  outcome: LessonOutcome;

  constructor(bookId: string, lessonId: string, lessonTitle: string, questionCount: number, correctCount: number,
    outcome: LessonOutcome) {
    this.bookId = bookId;
    this.lessonId = lessonId;
    this.lessonTitle = lessonTitle;
    this.questionCount = questionCount;
    this.correctCount = correctCount;
    this.outcome = outcome;
  }

  get accuracy(): number {
    return this.questionCount > 0 ? this.correctCount / this.questionCount : 0;
  }
}
