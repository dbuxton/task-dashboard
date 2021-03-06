// Generated by CoffeeScript 1.6.3
(function() {
  var AUTOREFRESH_MINUTES, Card, CardView, Cards, CardsView, CompletedCardView, CompletedCardsView, CustomerRequestsView, GCAL_FEED_URL_LS_KEY, List, Lists, NAME_TO_INITIALS_MAPPING, OverdueCardsView, PIPEDRIVE_API_BASE, PIPEDRIVE_API_KEY_LS_KEY, REFRESH_CARDS_INTERVAL_SECONDS, TRELLO_BOARDS, UnscheduledCardView, UnscheduledCardsView, User, Users, calendarCards, getBoardCards, getHash, getMonday, getPipedriveActivities, handleFeed, loadBoardLists, loadBoards, loadCurrentMember, loadInitialData, loadMembers, setAvatarStyle, trelloLists, trelloUsers, updateCalendar, updateGcal, updatePipedrive;

  TRELLO_BOARDS = ['UsP5zlas', 'cZd9apE5', 'zkkCd4kN', 'ljHglwed'];

  REFRESH_CARDS_INTERVAL_SECONDS = 60;

  AUTOREFRESH_MINUTES = 15;

  GCAL_FEED_URL_LS_KEY = 'arachnysDashboardFeedUrl';

  PIPEDRIVE_API_KEY_LS_KEY = 'arachnysPipedriveApiKey';

  PIPEDRIVE_API_BASE = 'https://api.pipedrive.com/v1';

  NAME_TO_INITIALS_MAPPING = {
    "David Buxton": "DB",
    "Mike Cerillo": "MC",
    "Lynn Petesch": "L",
    "Aaron Tanner": "AT",
    "Hollie Tu": "HT",
    "Enric Castane": "EC",
    "Minna Cowper-Coles": "MCC",
    "Board Members": "BM",
    "david": "DB",
    "harry": "HW",
    "matthew": "MB",
    "mateusz": "MK",
    "james": "JP",
    "Nicole Bossieux": "NB",
    "Omar Khan": "OK"
  };

  List = Backbone.Model.extend({
    defaults: {
      url: null,
      name: "No name"
    }
  });

  User = Backbone.Model.extend({
    defaults: {
      initials: "NI",
      name: "No name",
      avatarHash: null
    }
  });

  Card = Backbone.Model.extend({
    defaults: {
      id: null,
      name: "No name",
      url: "#",
      start: null,
      end: null,
      listId: null,
      archived: false,
      complete: true,
      display: false,
      inPast: false,
      userIds: [],
      initials: [],
      source: "trello",
      dueInPreviousWeek: false,
      avatarClasses: '',
      statusClasses: '',
      classString: ''
    },
    initialize: function() {
      this._inPast();
      this.calculateAttributes();
      this.bind('change:start', '_inPast');
      return this.bind('change', '@calculateAttributes');
    },
    _inPast: function() {
      var now, startDate;
      if (!this.get('start')) {
        this.set('inPast', false);
        return;
      }
      now = new Date();
      startDate = new Date(this.get('start'));
      this.set('inPast', (now.getTime() - startDate.getTime()) > 0);
      return _.debounce(updateCalendar, 300);
    },
    calculateAttributes: function() {
      var avatarStyles, classString, due, firstOfWeek, i, initials, list, now, user, userId, userIds, _i, _len;
      classString = "card event-large";
      userIds = this.get('userIds');
      now = new Date();
      firstOfWeek = getMonday(now).getTime();
      initials = [];
      if (this.get('start') === 0) {
        this.set('start', null);
      }
      if ((userIds != null) && userIds.length > 0) {
        for (_i = 0, _len = userIds.length; _i < _len; _i++) {
          userId = userIds[_i];
          user = trelloUsers.get(userId);
          if (user) {
            initials.push(user.get('initials'));
          }
        }
        avatarStyles = (function() {
          var _j, _len1, _results;
          _results = [];
          for (_j = 0, _len1 = initials.length; _j < _len1; _j++) {
            i = initials[_j];
            _results.push("avatar-" + i);
          }
          return _results;
        })();
        this.set('initials', initials.join(', '));
        this.set('avatarClasses', avatarStyles.join(' '));
        this.set("title", "" + (this.get('name')) + " [" + (this.get('initials')) + "]");
      } else {
        this.set("title", this.get('name'));
      }
      if (this.get('source') === 'gcal') {
        classString = "" + classString + " event-gcal";
      }
      if (this.get('source') === 'trello') {
        if (this.get('inPast')) {
          this.set('statusClasses', "event-in-past");
        }
        list = trelloLists.get(this.get('listId'));
        if (list.get('name') === "Complete") {
          this.set('complete', true);
          this.set('display', true);
          this.set('statusClasses', "" + (this.get('statusClasses')) + " event-fade event-success");
        } else if (list.get('name') === "In progress") {
          this.set('display', true);
          this.set('statusClasses', "" + (this.get('statusClasses')) + " event-progress");
        } else if (list.get('name') === "Milestones") {
          this.set('display', true);
          this.set('statusClasses', "" + (this.get('statusClasses')) + " event-milestone");
        } else if (list.get('name') === 'Scheduled') {
          this.set('display', true);
          this.set('statusClasses', "" + (this.get('statusClasses')) + " event-not-started");
        }
        if (this.get('start') != null) {
          due = new Date(this.get('start')).getTime();
          if (due < firstOfWeek) {
            this.set('dueInPreviousWeek', true);
          }
        }
      }
      return this.set('class', "" + classString + " " + (this.get('statusClasses')) + " " + (this.get('avatarClasses')));
    },
    viewEvent: function() {
      return window.open(url);
    }
  });

  Cards = Backbone.Collection.extend({
    localStorage: new Backbone.LocalStorage("Cards"),
    model: Card
  });

  Users = Backbone.Collection.extend({
    localStorage: new Backbone.LocalStorage("Users"),
    model: User
  });

  Lists = Backbone.Collection.extend({
    localStorage: new Backbone.LocalStorage("Lists"),
    model: List
  });

  trelloUsers = new Users;

  trelloLists = new Lists;

  calendarCards = new Cards;

  CardView = Backbone.View.extend({
    template: _.template("<div class=\"card-inner <%= avatarClasses %>\">\n    <i class='fa fa-trello'></i>\n    <%= name %><% if (initials.length > 0) { %> [<%= initials %>] <% } %>\n</div>"),
    initialize: function() {
      return this.listenTo(this.model, 'change', this.render);
    },
    render: function() {
      this.$el.html(this.template(this.model.toJSON()));
      return this;
    },
    events: function() {
      return {
        "click": "openCard"
      };
    },
    openCard: function() {
      return window.open(this.model.get('url'), '_blank');
    }
  });

  CompletedCardView = CardView.extend({
    className: function() {
      return "col-md-3 card";
    }
  });

  UnscheduledCardView = CardView.extend({
    template: _.template("<%= name %><% if (initials.length > 0) { %> [<%= initials %>] <% } %>"),
    className: function() {
      return "card " + (this.model.get('avatarClasses')) + " " + (this.model.get('statusClasses')) + " event-large";
    }
  });

  CardsView = Backbone.View.extend({
    initialize: function() {
      this.listenTo(calendarCards, 'add', this.addOne);
      return this.listenTo(calendarCards, 'reset', this.addAll);
    },
    addAll: function() {
      var unscheduled;
      unscheduled = new Cards(calendarCards);
      return unscheduled.each(this.addOne, this);
    }
  });

  CompletedCardsView = CardsView.extend({
    el: '#completed-cards',
    cardView: CompletedCardView,
    addOne: function(card) {
      var view;
      if (card.get('archived') === true) {
        view = new this.cardView({
          model: card
        });
        return this.$el.append(view.render().el);
      }
    }
  });

  UnscheduledCardsView = CardsView.extend({
    el: '#no-due-date',
    cardView: UnscheduledCardView,
    addOne: function(card) {
      var view;
      if (card.get('source') !== 'trello') {
        return;
      }
      if (card.get('display') !== true) {
        return;
      }
      if (card.get('archived') === false && card.get('start') === null) {
        if (card.get('complete') === true) {
          return;
        }
        view = new this.cardView({
          model: card
        });
        return this.$el.append(view.render().el);
      }
    }
  });

  OverdueCardsView = UnscheduledCardsView.extend({
    el: '#overdue',
    addOne: function(card) {
      var view;
      if (card.get('source') !== 'trello') {
        return;
      }
      if (card.get('archived') === false && card.get('dueInPreviousWeek') === true) {
        if (card.get('complete') === true) {
          return;
        }
        view = new this.cardView({
          model: card
        });
        return this.$el.append(view.render().el);
      }
    }
  });

  CustomerRequestsView = CompletedCardsView.extend({
    el: '#customer-requests',
    addOne: function(card) {
      var view;
      if (card.get('name').toLowerCase().indexOf('[customer request]') !== -1) {
        if (card.get('complete') === true || card.get('archived') === true) {
          return;
        }
        view = new this.cardView({
          model: card
        });
        return this.$el.append(view.render().el);
      }
    }
  });

  $(function() {
    var completedCards, customerRequestsView, overdueCards, unscheduledCards;
    window.calendar = $('#calendar').calendar({
      first_day: 1,
      show_weekends: 0,
      events_source: []
    });
    window.calendar2 = $('#calendar2').calendar({
      first_day: 1,
      show_weekends: 0,
      events_source: []
    });
    window.calendar.view('week');
    window.calendar2.view('week');
    window.calendar2.navigate('next');
    setTimeout("location.reload(true);", 1000 * 60 * AUTOREFRESH_MINUTES);
    completedCards = new CompletedCardsView();
    unscheduledCards = new UnscheduledCardsView();
    overdueCards = new OverdueCardsView();
    return customerRequestsView = new CustomerRequestsView();
  });

  window.onAuthorize = function() {
    updateLoggedIn();
    $("#output").empty();
    return loadInitialData().done(function() {
      getBoardCards();
      return updateGcal();
    });
  };

  getMonday = function(d) {
    var day, diff, _ref;
    d = new Date(d);
    day = d.getDay();
    diff = d.getDate() - day + ((_ref = day === 0) != null ? _ref : -{
      6: 1
    });
    return new Date(d.setDate(diff));
  };

  getBoardCards = function() {
    var firstOfWeek, now;
    now = new Date();
    firstOfWeek = getMonday(now);
    $.each(TRELLO_BOARDS, function(idx, boardId) {
      return Trello.get("boards/" + boardId + "/cards?filter=visible", function(cards) {
        var card, _i, _len;
        for (_i = 0, _len = cards.length; _i < _len; _i++) {
          card = cards[_i];
          calendarCards.create({
            id: card.url,
            name: card.name,
            userIds: card.idMembers,
            listId: card.idList,
            url: card.url,
            start: new Date(card.due).getTime(),
            end: new Date(card.due).getTime(),
            complete: false
          });
        }
        return updateCalendar();
      });
    });
    $.each(TRELLO_BOARDS, function(idx, boardId) {
      return Trello.get("boards/" + boardId + "/cards?filter=closed&limit=100", function(cards) {
        var card, cardClosedDate, daysAgoClosed, _i, _len;
        for (_i = 0, _len = cards.length; _i < _len; _i++) {
          card = cards[_i];
          cardClosedDate = new Date(card.dateLastActivity);
          daysAgoClosed = (now - cardClosedDate) / 1000 / 3600 / 24;
          if (daysAgoClosed <= 7.0) {
            calendarCards.create({
              id: card.url,
              name: card.name,
              userIds: card.idMembers,
              listId: card.idList,
              url: card.url,
              start: new Date(card.due).getTime(),
              end: new Date(card.due).getTime(),
              archived: true
            });
          }
        }
        return updateCalendar();
      });
    });
    return setTimeout(getBoardCards, REFRESH_CARDS_INTERVAL_SECONDS * 1000);
  };

  setAvatarStyle = function(initials, avatarHash) {
    var imageUrl;
    imageUrl = "https://trello-avatars.s3.amazonaws.com/" + avatarHash + "/30.png";
    return $("<style type='text/css'>.avatar-" + initials + " { background-image: url('" + imageUrl + "'); background-repeat: no-repeat; background-position-x:right; } </style>").appendTo('head');
  };

  loadCurrentMember = function() {
    var deferred;
    deferred = $.Deferred();
    Trello.members.get("me", function(member) {
      $("#fullName").text(member.fullName);
      return deferred.resolve();
    });
    return deferred.promise();
  };

  loadMembers = function() {
    var deferred;
    deferred = $.Deferred();
    Trello.get("organizations/arachnys1/members?fields=all", function(members) {
      var member, _i, _len;
      for (_i = 0, _len = members.length; _i < _len; _i++) {
        member = members[_i];
        trelloUsers.create({
          id: member.id,
          name: member.fullName,
          initials: member.initials,
          avatarHash: member.avatarHash
        });
        setAvatarStyle(member.initials, member.avatarHash);
      }
      return deferred.resolve();
    });
    return deferred.promise();
  };

  loadBoardLists = function(boardId) {
    var deferred;
    deferred = $.Deferred();
    Trello.get("boards/" + boardId + "/lists", function(lists) {
      var list, _i, _len;
      for (_i = 0, _len = lists.length; _i < _len; _i++) {
        list = lists[_i];
        trelloLists.create({
          id: list.id,
          name: list.name
        });
      }
      return deferred.resolve();
    });
    return deferred.promise();
  };

  loadBoards = function() {
    var deferred;
    deferred = $.Deferred();
    $.when(TRELLO_BOARDS.map(loadBoardLists)).done(function() {
      return deferred.resolve();
    });
    return deferred.promise();
  };

  loadInitialData = function() {
    var deferred;
    deferred = $.Deferred();
    $.when(loadCurrentMember(), loadMembers(), loadBoards()).done(function() {
      return deferred.resolve();
    });
    return deferred.promise();
  };

  window.updateLoggedIn = function() {
    var isLoggedIn;
    isLoggedIn = Trello.authorized();
    $("#loggedout").toggle(!isLoggedIn);
    return $("#loggedin").toggle(isLoggedIn);
  };

  window.logout = function() {
    Trello.deauthorize();
    return updateLoggedIn();
  };

  window.getFeed = function() {
    var service;
    service = new google.gdata.calendar.CalendarService('arachnys');
    return service.getEventsFeed(FEED_URL, handleFeed, handleError);
  };

  getHash = function(str) {
    var char, code, hash, _i, _len;
    hash = 0;
    if (str.length === 0) {
      return 0;
    }
    for (_i = 0, _len = str.length; _i < _len; _i++) {
      char = str[_i];
      code = char.charCodeAt(0);
      hash = ((hash << 5) - hash) + code;
      hash |= 0;
    }
    return hash;
  };

  handleFeed = function(feed) {
    var entries, entry, initials, user, _i, _len;
    entries = feed.entry;
    for (_i = 0, _len = entries.length; _i < _len; _i++) {
      entry = entries[_i];
      initials = NAME_TO_INITIALS_MAPPING[entry.title.$t.toLowerCase()];
      if (!initials) {
        console.error("No initials for", entry.title.$t.toLowerCase());
        return;
      }
      user = trelloUsers.findWhere({
        initials: initials
      });
      if (user == null) {
        console.error("User with initials " + initials + " not found");
        return;
      }
      calendarCards.create({
        id: getHash(entry.id.$t),
        name: "" + entry.title.$t + " on tech duty",
        url: entry.link[0].href,
        start: new Date(entry['gd$when'][0]['startTime']).getTime(),
        end: new Date(entry['gd$when'][0]['endTime']).getTime(),
        userIds: [user.id],
        source: 'gcal'
      });
    }
    return updateCalendar();
  };

  updateCalendar = function() {
    var flat, item, _i, _len, _ref;
    flat = [];
    _ref = calendarCards.where({
      archived: false
    });
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      flat.push(item.toJSON());
    }
    window.calendar.setOptions({
      events_source: flat
    });
    window.calendar2.setOptions({
      events_source: flat
    });
    window.calendar.view();
    return window.calendar2.view();
  };

  updateGcal = function() {
    var feedUrl, url;
    feedUrl = JSON.parse(localStorage.getItem(GCAL_FEED_URL_LS_KEY));
    if (!feedUrl) {
      url = window.prompt('Enter Google Calendar feed URL for tech rota (should end with /full)');
      localStorage.setItem(GCAL_FEED_URL_LS_KEY, JSON.stringify(url));
      feedUrl = JSON.parse(localStorage.getItem(GCAL_FEED_URL_LS_KEY));
    }
    if (feedUrl) {
      return $.getJSON("" + feedUrl + "?alt=json-in-script&callback=?", function(data) {
        handleFeed(data.feed);
        return setTimeout(updateGcal, REFRESH_CARDS_INTERVAL_SECONDS * 1000);
      });
    } else {
      return window.alert('Not possible to load Google Calendar data');
    }
  };

  updatePipedrive = function() {
    var apiKey, key;
    apiKey = JSON.parse(localStorage.getItem(PIPEDRIVE_API_KEY_LS_KEY));
    if (!apiKey) {
      key = window.prompt('Enter Pipedrive API key');
      localStorage.setItem(PIPEDRIVE_API_KEY_LS_KEY, JSON.stringify(key));
      apiKey = JSON.parse(localStorage.getItem(PIPEDRIVE_API_KEY_LS_KEY));
    }
    if (apiKey) {
      setTimeout(updatePipedrive, REFRESH_CARDS_INTERVAL_SECONDS * 1000);
      return getPipedriveActivities(apiKey);
    } else {
      return window.alert('Not possible to load Pipedrive data');
    }
  };

  getPipedriveActivities = function(apiKey) {
    window.calendarEvents.pipedrive = [];
    return $.getJSON("" + PIPEDRIVE_API_BASE + "/users?api_token=" + apiKey, function(data) {
      var u, user, userHash, users, _i, _j, _len, _len1, _results;
      users = data.data;
      userHash = {};
      for (_i = 0, _len = users.length; _i < _len; _i++) {
        u = users[_i];
        userHash[u.id] = u;
      }
      _results = [];
      for (_j = 0, _len1 = users.length; _j < _len1; _j++) {
        user = users[_j];
        _results.push($.getJSON("" + PIPEDRIVE_API_BASE + "/activities/?done=0&api_token=" + apiKey + "&user_id=" + user.id, function(activityData) {
          var activity, date, initials, member, metadata, _k, _len2, _ref;
          if (activityData.data == null) {
            return;
          }
          _ref = activityData.data;
          for (_k = 0, _len2 = _ref.length; _k < _len2; _k++) {
            activity = _ref[_k];
            date = new Date(activity.due_date).getTime();
            user = userHash[activity.user_id];
            initials = NAME_TO_INITIALS_MAPPING[user.name];
            if ((!initials) || (organizationMembersInitials[initials] == null)) {
              console.error("No initials for", user);
              return;
            }
            member = organizationMembersInitials[initials];
            metadata = formatCardMetaData([member.id]);
            window.calendarEvents.pipedrive.push({
              id: activity.id,
              title: "" + activity.subject + " " + metadata.membersString,
              url: "https://app.pipedrive.com/org/details/" + activity.org_id,
              start: date,
              end: date,
              "class": "event-warning " + metadata.avatarString + " event-large"
            });
          }
          return updateCalendar();
        }));
      }
      return _results;
    });
  };

  window.getEventLine = function(eventHash, idx) {
    var hasItem, k, ret, v;
    ret = {};
    hasItem = false;
    for (k in eventHash) {
      v = eventHash[k];
      if (idx < v.length) {
        hasItem = true;
        ret[k] = v[idx];
      } else {
        ret[k] = null;
      }
    }
    if (hasItem) {
      return ret;
    } else {
      return {};
    }
  };

}).call(this);
