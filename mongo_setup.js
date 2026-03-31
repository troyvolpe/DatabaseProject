use('gym_mongo_db');

db.dropDatabase();

db.members.createIndex({ email: 1 }, { unique: true });
db.classSessions.createIndex({ startsAt: 1, trainerId: 1 });
db.enrollments.createIndex({ memberId: 1, sessionId: 1 }, { unique: true });

const plans = [
  { _id: 1, name: 'Basic-12', monthlyFee: 29.99 },
  { _id: 2, name: 'Standard-12', monthlyFee: 49.99 },
  { _id: 3, name: 'Premium-12', monthlyFee: 79.99 }
];
db.membershipPlans.insertMany(plans);

const employees = [];
for (let i = 1; i <= 10; i += 1) {
  employees.push({
    _id: i,
    firstName: `Emp${i}`,
    lastName: 'Trainer',
    role: 'trainer',
    salary: 45000 + i * 1000
  });
}
db.employees.insertMany(employees);

const classTemplates = [
  { _id: 1, className: 'Morning HIIT', maxCapacity: 24 },
  { _id: 2, className: 'Lunch Yoga', maxCapacity: 30 },
  { _id: 3, className: 'Strength 101', maxCapacity: 20 }
];
db.classTemplates.insertMany(classTemplates);

const sessions = [];
for (let i = 1; i <= 30; i += 1) {
  const start = new Date();
  start.setDate(start.getDate() + (i % 10));
  start.setHours(6 + (i % 6) * 2, 0, 0, 0);
  const end = new Date(start);
  end.setMinutes(end.getMinutes() + 45);

  sessions.push({
    _id: i,
    classId: ((i - 1) % 3) + 1,
    trainerId: ((i - 1) % 10) + 1,
    startsAt: start,
    endsAt: end
  });
}
db.classSessions.insertMany(sessions);

const goals = ['Weight Loss', 'Muscle Gain', 'Endurance'];
const members = [];
for (let i = 1; i <= 60; i += 1) {
  members.push({
    _id: i,
    firstName: `Member${i}`,
    lastName: `User${i}`,
    email: `member${i}@gym.local`,
    status: i % 20 === 0 ? 'paused' : 'active',
    currentMembership: {
      planId: ((i - 1) % 3) + 1,
      isActive: true
    },
    goals: [{ goalName: goals[(i - 1) % 3], setOn: new Date() }]
  });
}
db.members.insertMany(members);

const enrollments = [];
for (let i = 1; i <= 60; i += 1) {
  enrollments.push(
    { memberId: i, sessionId: ((i - 1) % 30) + 1, attendanceStatus: 'enrolled', enrolledAt: new Date() },
    { memberId: i, sessionId: ((i + 9) % 30) + 1, attendanceStatus: i % 3 === 0 ? 'attended' : 'enrolled', enrolledAt: new Date() }
  );
}
db.enrollments.insertMany(enrollments);

print('\n=== Query 1: member + plan (lookup) ===');
db.members.aggregate([
  {
    $lookup: {
      from: 'membershipPlans',
      localField: 'currentMembership.planId',
      foreignField: '_id',
      as: 'plan'
    }
  },
  { $unwind: '$plan' },
  {
    $project: {
      _id: 0,
      memberId: '$_id',
      memberName: { $concat: ['$firstName', ' ', '$lastName'] },
      planName: '$plan.name',
      monthlyFee: '$plan.monthlyFee'
    }
  },
  { $limit: 10 }
]).forEach(doc => printjson(doc));

print('\n=== Query 2: session occupancy (group + lookup) ===');
db.enrollments.aggregate([
  { $group: { _id: '$sessionId', enrolledCount: { $sum: 1 } } },
  {
    $lookup: {
      from: 'classSessions',
      localField: '_id',
      foreignField: '_id',
      as: 'session'
    }
  },
  { $unwind: '$session' },
  {
    $project: {
      _id: 0,
      sessionId: '$_id',
      startsAt: '$session.startsAt',
      enrolledCount: 1
    }
  },
  { $sort: { enrolledCount: -1 } },
  { $limit: 10 }
]).forEach(doc => printjson(doc));

print('\n=== Query 3: members above average enrollments ===');
db.enrollments.aggregate([
  { $group: { _id: '$memberId', classCount: { $sum: 1 } } },
  {
    $setWindowFields: {
      sortBy: { _id: 1 },
      output: {
        avgCount: {
          $avg: '$classCount',
          window: { documents: ['unbounded', 'unbounded'] }
        }
      }
    }
  },
  { $match: { $expr: { $gt: ['$classCount', '$avgCount'] } } },
  {
    $lookup: {
      from: 'members',
      localField: '_id',
      foreignField: '_id',
      as: 'member'
    }
  },
  { $unwind: '$member' },
  {
    $project: {
      _id: 0,
      memberId: '$member._id',
      memberName: { $concat: ['$member.firstName', ' ', '$member.lastName'] },
      classCount: 1,
      avgCount: { $round: ['$avgCount', 2] }
    }
  },
  { $limit: 10 }
]).forEach(doc => printjson(doc));

print('\nMongo setup complete.');
