# coding: utf-8

require "tk"

#マス(盤の1区画)の幅
SWIDTH = 70
#盤の周囲のマージン(座標の数字を書くスペース)
MARGIN = 20
#メッセージの表示領域の高さ(盤の下の空白領域)
MHEIGHT = 80
#ボタンの表示領域の高さ
BHEIGHT = 25

# 盤に配置する石，壁，空白
BLACK = 1
WHITE = -1
EMPTY = 0
WALL = 2
	
# 石を打てる方向（２進数のビットフラグ）
NONE = 0
UPPER = 1
UPPER_LEFT = 2
LEFT = 4
LOWER_LEFT = 8
LOWER = 16
LOWER_RIGHT = 32
RIGHT = 64
UPPER_RIGHT = 128

# 盤のサイズと手数の最大数
BOARDSIZE = 8
MAXTURNS = 60

# minmaxで探索する深さ(先を読む手数)
LIMIT = 5

# 残り手数がLIMIT2以下になったら最後まで読み切る
LIMIT2 = 10

# アルゴリズム変更のタイミング
LIMIT3 = 20

#スコアの最大値
MAXSCORE = 100000
	
# 盤を表すクラスの定義
class Board
  def makeWindow
    #盤の幅と高さ
    w = SWIDTH * 8 + MARGIN * 2
    h = SWIDTH * 8 + MARGIN * 2

    #ルートウィンドウ
    top = TkRoot.new(title:"Othello",width:w,height:h+MHEIGHT+BHEIGHT)

    #盤を書くためのキャンパス
    canvas = TkCanvas.new(top,width:w,height:h,borderwidth:0,highlightthickness:0,background:"darkgreen").place("x"=>0,"y"=>0)

    #盤の周囲の文字
    for i in 0..BOARDSIZE-1 do
      TkcText.new(canvas,i*SWIDTH+SWIDTH/2+MARGIN-4,MARGIN-10,text:("a".ord + i).chr,fill:"white")
      TkcText.new(canvas,10,i*SWIDTH+SWIDTH/2+MARGIN,text:(i+1).to_s,fill:"white")
    end
    #8x8のマス目を描く
    self.drawBoard(canvas)

    #終了ボタンと再スタートボタン
    bframe = TkFrame.new(top,width:w,height:BHEIGHT).place('x'=>'0','y'=>h)
    TkButton.new(bframe,text:'プログラム終了',command:proc{exit}).pack('side'=>'left')
    TkButton.new(bframe,text:'再スタート',command:proc{reset(canvas)}).pack('side'=>'left')

    #動作確認用メッセージの用事領域.TkTextでテキストを表示
    #TkScrollbarのスクロールバー付きにする
    frame = TkFrame.new(top,width:w,background:"red",height:MHEIGHT).place("x"=>0,"y"=>h+BHEIGHT)
    yscr = TkScrollbar.new(frame).pack("fill"=>"y","side"=>"right","expand"=>true)
    text = TkText.new(frame,height:6).pack("fill"=>"both","side"=>"right","expand"=>true)
    text.yscrollbar(yscr)

    #盤がクリックされた場合の動作を定義。クリックされるとclickBoardが呼び出される
    canvas.bind("ButtonPress-1",proc{|x,y|self.clickBoard(canvas,text,x,y)},"%x %y")
    return canvas
  end

  def reset(canvas)
    res = TkDialog.new('message'=>'黒と白,どちらにします？','buttons'=>'黒にする 白にする','default'=>0).value

    #盤を初期化
    self.init

    #人間が白を選んだ場合、まずコンピュータが黒で(4,3)に打つ
    if res == 1
      self.move(4,3)
    end

    #盤と石を再描画
    self.drawBoard(canvas)
    self.drawAllDisks(canvas)
  end

#盤の区画を描画
  def drawBoard(canvas)
    for x in 0..BOARDSIZE-1 do
      for y in 0.. BOARDSIZE-1 do
        rect = TkcRectangle.new(canvas,MARGIN+x*SWIDTH,MARGIN+y*SWIDTH,MARGIN+(x+1)*SWIDTH,MARGIN+(y+1)*SWIDTH)
        rect.configure(fill:"#00aa00")
      end
    end
  end

  # 盤を表す配列
  @rawBoard = nil
  # 石を打てる場所を格納する配列
  @movableDir = nil
	
  # 盤を（再）初期化
  def init
    @turns = 0
    @current_color = BLACK
    
    # 配列が未作成であれば作成する
    if @rawBoard == nil
      @rawBoard = Array.new(BOARDSIZE + 2).map{Array.new(BOARDSIZE + 2,EMPTY)}
    end
    if @movebleDir == nil
      @movableDir = Array.new(BOARDSIZE + 2).map{Array.new(BOARDSIZE + 2,NONE)}
    end
  
    # @rawBoardを初期化，周囲を壁(WALL)で囲む
    for x in 0..BOARDSIZE + 1 do
      for y in 0..BOARDSIZE + 1 do
        @rawBoard[x][y] = EMPTY
        if y == 0 or y == BOARDSIZE + 1 or x == 0 or x == BOARDSIZE + 1
	  @rawBoard[x][y] = WALL
        end
      end
    end
	
    # 石を配置
    @rawBoard[4][4] = WHITE
    @rawBoard[5][5] = WHITE
    @rawBoard[4][5] = BLACK
    @rawBoard[5][4] = BLACK

       self.initMovable
  end
  # ここに initMovableとcheckmobilityの定義を追加
  # @movableDirの値を設定
  def initMovable
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        dir = self.checkMobility(x,y,@current_color)
        @movableDir[x][y]=dir
      end
    end
  end

  #石を打てる方向を調べる
  def checkMobility(x1,y1,color)
    #石が置いてあれば打てない
    if @rawBoard[x1][y1]!=EMPTY
      return NONE
    end

    #打てる方向dirを初期化
    dir = NONE

    #上
    x = x1
    y = y1
    if @rawBoard[x][y-1]==-color
      y = y-1
      while(@rawBoard[x][y]==-color)
        y = y-1
      end
      if @rawBoard[x][y]==color
        dir|=UPPER
      end
    end

    #下
    x = x1
    y = y1
    if @rawBoard[x][y+1]==-color
      y = y+1
      while(@rawBoard[x][y]==-color)
        y = y+1
      end
      if @rawBoard[x][y]==color
        dir|=LOWER
      end
    end

    #左
    x = x1
    y = y1
    if @rawBoard[x-1][y]==-color
      x = x-1
      while(@rawBoard[x][y]==-color)
        x = x-1
      end
      if @rawBoard[x][y]==color
        dir|=LEFT
      end
    end

    #右
    x = x1
    y = y1
    if @rawBoard[x+1][y]==-color
      x = x+1
      while(@rawBoard[x][y]==-color)
        x = x+1
      end
      if @rawBoard[x][y]==color
        dir|=RIGHT
      end
    end

    #右上
    x = x1
    y = y1
    if @rawBoard[x+1][y-1]==-color
      x = x+1
      y = y-1
      while(@rawBoard[x][y]==-color)
        x = x+1
        y = y-1
      end
      if @rawBoard[x][y]==color
        dir|=UPPER_RIGHT
      end
    end

    #右下
    x = x1
    y = y1
    if @rawBoard[x+1][y+1]==-color
      x = x+1
      y = y+1
      while(@rawBoard[x][y]==-color)
        x = x+1
        y = y+1
      end
      if @rawBoard[x][y]==color
        dir|=LOWER_RIGHT
      end
    end

    #左上
    x = x1
    y = y1
    if @rawBoard[x-1][y-1]==-color
      x = x-1
      y = y-1
      while(@rawBoard[x][y]==-color)
        x = x-1
        y = y-1
      end
      if @rawBoard[x][y]==color
        dir|=UPPER_LEFT
      end
    end

    #左下
    x = x1
    y = y1
    if @rawBoard[x-1][y+1]==-color
      x = x-1
      y = y+1
      while(@rawBoard[x][y]==-color)
        x = x-1
        y = y+1
      end
      if @rawBoard[x][y]==color
        dir|=LOWER_LEFT
      end
    end

    return dir
  end

  def flipDisks(x1,y1)
    dir = @movableDir[x1][y1]
    @rawBoard[x1][y1] = @current_color

    #上
    x = x1
    y = y1
    if(dir & UPPER) != NONE
      while @rawBoard[x][y-1] != @current_color
        y = y-1
        @rawBoard[x][y] = @current_color
      end
    end

    #下
    x = x1
    y = y1
    if(dir & LOWER) != NONE
      while @rawBoard[x][y+1] != @current_color
        y = y+1
        @rawBoard[x][y] = @current_color
      end
    end

    #左
    x = x1
    y = y1
    if(dir & LEFT) != NONE
      while @rawBoard[x-1][y] != @current_color
        x = x-1
        @rawBoard[x][y] = @current_color
      end
    end

    #右
    x = x1
    y = y1
    if(dir & RIGHT) != NONE
      while @rawBoard[x+1][y] != @current_color
        x = x+1
        @rawBoard[x][y] = @current_color
      end
    end

    #右上
    x = x1
    y = y1
    if(dir & UPPER_RIGHT) != NONE
      while @rawBoard[x+1][y-1] != @current_color
        x = x+1
        y = y-1
        @rawBoard[x][y] = @current_color
      end
    end

    #右下
    x = x1
    y = y1
    if(dir & LOWER_RIGHT) != NONE
      while @rawBoard[x+1][y+1] != @current_color
        x = x+1
        y = y+1
        @rawBoard[x][y] = @current_color
      end
    end

    #左上
    x = x1
    y = y1
    if(dir & UPPER_LEFT) != NONE
      while @rawBoard[x-1][y-1] != @current_color
        x = x-1
        y = y-1
        @rawBoard[x][y] = @current_color
      end
    end

    #左下
    x = x1
    y = y1
    if(dir & LOWER_LEFT) != NONE
      while @rawBoard[x-1][y+1] != @current_color
        x = x-1
        y = y+1
        @rawBoard[x][y] = @current_color
      end
    end
  end

  def isGameOver
    #60手に達していたら終了
    if @turns == MAXTURNS
      return true
    end

    #現在の手番(@current_color)で打てる場所があればfalseを返す
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if @movableDir[x][y]!=NONE
          return false
        end
      end
    end

    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if checkMobility(x,y,-@current_color) != NONE
          return false
        end
      end
    end

    return true
  end

  def isPass
    #現在の手番で打てる手があればfalseを返す
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if @movableDir[x][y]!=NONE
          return false
        end
      end
    end

    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if checkMobility(x,y,-@current_color) != NONE
          return true
        end
      end
    end

    return false
  end

  # ここに move と loop の定義を追加

  # 石を置き，ひっくり返す
  def move(x,y)
    if @movableDir[x][y] == NONE
      return false
    end
    
    self.flipDisks(x,y)
    @rawBoard[x][y] = @current_color
      
    @turns += 1
    @current_color = -1 * @current_color
    self.initMovable
      
    return true
  end

  #すべての石を描画
  def drawAllDisks(canvas)
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        #石の描画
        #@rawBoard[x][y]を参照し、その値がBLACKかWHITEなら以下を実行
        if @rawBoard[x][y]==BLACK
          disk = TkcOval.new(canvas,MARGIN+(x-1)*SWIDTH,MARGIN+(y-1)*SWIDTH,MARGIN+(x)*SWIDTH,MARGIN+(y)*SWIDTH)
          disk.configure(fill:"black")
        elsif @rawBoard[x][y]==WHITE
          disk = TkcOval.new(canvas,MARGIN+(x-1)*SWIDTH,MARGIN+(y-1)*SWIDTH,MARGIN+(x)*SWIDTH,MARGIN+(y)*SWIDTH)
          disk.configure(fill:"white")
        end
        #disk = TkcOval.new(...)で適切な位置に円を描く
        #disk.configure(...)で石を描画する色(白か黒)を設定する
      end
    end
  end

  #石の数を数える
  def numDisks
    score = 0
    #単純に「石の数が多いほど有利！」と考えて、
    #「自分(@current_color)の数」-「相手(-@current_color)の石の数」
    #を計算し、scoreに代入しreturnする
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if @rawBoard[x][y] == @current_color
          score+=1
        elsif @rawBoard[x][y] == -@current_color
          score-=1
        end
      end
    end
    return score
  end

  #着手可能数
  def movility
    score = 0
    #打てる場所が多いほど有利と考えて
    #「自分の打てるマスの数」-「相手の打てるマスの数」を計算する
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if @movableDir[x][y]!=NONE
          score+=1
        end
        #自分の手数:@movabledir[x][y]の値を調べて、
        #NONEでなければ
        #scoreに1加算する
        if self.checkMobility(x,y,-@current_color) !=NONE
          score-=1
        end
        #相手の手数self.checkMobility(x,y,-@current_color)の値を調べて
        #NONEでなければ
        #scoreを1減算する
      end
    end
    return score
  end

  #隅に石が置かれているかを評価する
  def checkCorner
    score = 0

    for x in [1,BOARDSIZE] do
      for y in [1,BOARDSIZE] do
        if @rawBoard[x][y] == @current_color
          score +=1
        elsif @rawBoard[x][y] == -@current_color
          score -=1
        end
        # @rawBoard[x][y]が自分の石(@current_color)ならば
        # scoreに1加算
        # @rawBoard[x][y]が相手の石(-@current_color)ならば
        # scoreに1減算
      end
    end
    return score
  end

  def finalweight
    score = 0
    # 50点4マス
    for x in [1,BOARDSIZE] do
      for y in [1,BOARDSIZE] do
        if @rawBoard[x][y] == @current_color
          score +=50
        elsif @rawBoard[x][y] == -@current_color
          score -=50
        end
      end
    end

    # -20点8マス
    for x in [1,8] do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 20
        elsif @rawBoard[x][y] == -@current_color
          score += 20
        end

        if @rawBoard[y][x] == @current_color
          score -= 20
        elsif @rawBoard[y][x] == -@current_color
          score += 20
        end
      end
    end
    
    # 20点8マス
    for x in [1,8] do
      for y in [3,6] do
        if @rawBoard[x][y] == @current_color
          score += 20
        elsif @rawBoard[x][y] == -@current_color
          score -= 20
        end

        if @rawBoard[y][x] == @current_color
          score += 20
        elsif @rawBoard[y][x] == -@current_color
          score -= 20
        end
      end
    end

    # 5点8マス
    for x in [1,8] do
      for y in [4,5] do
        if @rawBoard[x][y] == @current_color
          score += 5
        elsif @rawBoard[x][y] == -@current_color
          score -= 5
        end

        if @rawBoard[y][x] == @current_color
          score += 5
        elsif @rawBoard[y][x] == -@current_color
          score -= 5
        end
      end
    end

    # -60点4マス
    for x in [2,7] do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 60
        elsif @rawBoard[x][y] == -@current_color
          score += 60
        end
      end
    end

    # 5点4マス
    for x in [3,6] do
      for y in [3,6] do
        if @rawBoard[x][y] == @current_color
          score += 5
        elsif @rawBoard[x][y] == -@current_color
          score -= 5
        end
      end
    end

    # 0点4マス(真ん中)

    # -1点16マス
    for x in 3..6 do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 1
        elsif @rawBoard[x][y] == -@current_color
          score += 1
        end

        if @rawBoard[y][x] == @current_color
          score -= 1
        elsif @rawBoard[y][x] == -@current_color
          score += 1
        end
      end
    end

    # 1点8マス
    for x in [3,6] do
      for y in [4,5] do
        if @rawBoard[x][y] == @current_color
          score += 1
        elsif @rawBoard[x][y] == -@current_color
          score -= 1
        end

        if @rawBoard[y][x] == @current_color
          score += 1
        elsif @rawBoard[y][x] == -@current_color
          score -= 1
        end
      end
    end

    return score
  end

  def kakutei
    score = 0
    # 左上
    if @rawBoard[1][1] == @current_color
      i = 1
      while i<8
        if @rawBoard[1][1+i] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[1+i][1] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end

    elsif @rawBoard[1][1] == -@current_color
      i = 1
      while i<8
        if @rawBoard[1][1+i] == -@current_color
          score -= 1
          i += 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[1+i][1] == -@current_color
          score -= 1
          i += 1
        else
          break
        end
      end
    end


    # 左下
    if @rawBoard[1][8] == @current_color
      i = 1
      while i<8
        if @rawBoard[1][8-i] == @current_color
          score += 1
          i += 1
        else 
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[1+i][8] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end

    elsif @rawBoard[1][8] == -@current_color
      i = 1
      while i<8
        if @rawBoard[1][8-i] == -@current_color
          score -= 1
          i += 1
        else 
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[1+i][8] == -@current_color
          score -= 1
          i += 1
        else
          break
        end
      end
    end

    # 右上
    if @rawBoard[8][1] == @current_color
      i = 1
      while i<8
        if @rawBoard[8-i][1] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[8][1+i] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end
      
    elsif @rawBoard[8][1] == -@current_color
      i = 1
      while i<8
        if @rawBoard[8-i][1] == -@current_color
          score -= 1
          i -= 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[8][1+i] == -@current_color
          score -= 1
          i += 1
        else
          break
        end
      end
    end

    # 右下
    if @rawBoard[8][8] == @current_color
      i = 1
      while i<8
        if @rawBoard[8-i][8] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[8][8-i] == @current_color
          score += 1
          i += 1
        else
          break
        end
      end
      
    elsif @rawBoard[8][8] == -@current_color
      i = 1
      while i<8
        if @rawBoard[8-i][8] == -@current_color
          score -= 1
          i -= 1
        else
          break
        end
      end

      i = 1
      while i<8
        if @rawBoard[8][8-i] == -@current_color
          score -= 1
          i += 1
        else
          break
        end
      end
    end
    return score
  end

  def weight
    score = 0
    # 100点4マス
    for x in [1,BOARDSIZE] do
      for y in [1,BOARDSIZE] do
        if @rawBoard[x][y] == @current_color
          score +=100
        elsif @rawBoard[x][y] == -@current_color
          score -=100
        end
      end
    end

    # -40点8マス
    for x in [1,8] do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 40
        elsif @rawBoard[x][y] == -@current_color
          score += 40
        end

        if @rawBoard[y][x] == @current_color
          score -= 40
        elsif @rawBoard[y][x] == -@current_color
          score += 40
        end
      end
    end
    
    # 20点8マス
    for x in [1,8] do
      for y in [3,6] do
        if @rawBoard[x][y] == @current_color
          score += 20
        elsif @rawBoard[x][y] == -@current_color
          score -= 20
        end

        if @rawBoard[y][x] == @current_color
          score += 20
        elsif @rawBoard[y][x] == -@current_color
          score -= 20
        end
      end
    end

    # 5点8マス
    for x in [1,8] do
      for y in [4,5] do
        if @rawBoard[x][y] == @current_color
          score += 5
        elsif @rawBoard[x][y] == -@current_color
          score -= 5
        end

        if @rawBoard[y][x] == @current_color
          score += 5
        elsif @rawBoard[y][x] == -@current_color
          score -= 5
        end
      end
    end

    # -80点4マス
    for x in [2,7] do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 80
        elsif @rawBoard[x][y] == -@current_color
          score += 80
        end
      end
    end

    # 5点4マス
    for x in [3,6] do
      for y in [3,6] do
        if @rawBoard[x][y] == @current_color
          score += 5
        elsif @rawBoard[x][y] == -@current_color
          score -= 5
        end
      end
    end

    # 0点4マス(真ん中)

    # -1点16マス
    for x in 3..6 do
      for y in [2,7] do
        if @rawBoard[x][y] == @current_color
          score -= 1
        elsif @rawBoard[x][y] == -@current_color
          score += 1
        end

        if @rawBoard[y][x] == @current_color
          score -= 1
        elsif @rawBoard[y][x] == -@current_color
          score += 1
        end
      end
    end

    # 1点8マス
    for x in [3,6] do
      for y in [4,5] do
        if @rawBoard[x][y] == @current_color
          score += 1
        elsif @rawBoard[x][y] == -@current_color
          score -= 1
        end

        if @rawBoard[y][x] == @current_color
          score += 1
        elsif @rawBoard[y][x] == -@current_color
          score -= 1
        end
      end
    end

    return score
  end

  #探索アルゴリズム
  def alphabeta(limit,mode,alpha,beta)
    #探索の深さ限度に到達したか、ゲーム終了の場合は評価値を返す
    if limit == 0 or self.isGameOver
      return self.evaluate(mode)
    end

    #パスの場合は、手番を変えて探索を続ける
    if self.isPass
      #状態を保存
      tmpBoard = @rawBoard.map(&:dup)
      tmpDir = @movableDir.map(&:dup)
      tmpTurns = @turns
      tmpColor = @current_color

      #色を反転して探索
      @current_color = -@current_color
      self.initMovable
      score = -alphabeta(limit-1,mode,-beta,-alpha)

      #元に戻す
      @rawBoard = tmpBoard.map(&:dup)
      @movableDir = tmpDir.map(&:dup)
      @turns = tmpTurns
      @current_color = tmpColor

      return score
    end




    #パスでない場合は、全ての打てるを生成し、スコアの最も高いものを探す
    for x in 1..BOARDSIZE do
      for y in 1..BOARDSIZE do
        if @movableDir[x][y]!=NONE
          tmpBoard = @rawBoard.map(&:dup)
          tmpDir = @movableDir.map(&:dup)
          tmpTurns = @turns
          tmpColor = @current_color
          #現在の盤の状態を保存
          #p.2の13-16行目(または上記の15-18行目)と同様に
          #盤の状態を保存するコードを書く

          #石を打つ
          self.move(x,y)

          score = -alphabeta(limit-1,mode,-beta,-alpha)
          #minmaxを呼び出す
          #p.2の29行目と同様に、
          #minmaxを呼び出して、得られたスコアをscoreに代入するコードを書く

          @rawBoard = tmpBoard.map(&:dup)
          @movableDir = tmpDir.map(&:dup)
          @turns = tmpTurns
          @current_color = tmpColor
          #盤の状態を元に戻す
          #p.3の34-37行目(または上記の26-29行目)と同様に、
          #盤の状態を元に戻すコードを書く

          if score > alpha
            alpha = score
          end

          if alpha >= beta
            return alpha
          end

        end
      end
    end

    return alpha
  end



  #評価関数(暫定版)
  def evaluate(mode)
    w1 = 30
    w2 = 1
    w3 = 1000

    if mode == 1
      score = self.numDisks
    elsif mode == 2
      score = w1*self.movility + w2*self.finalweight + w3*self.kakutei
    else
      score = w1*self.movility + w2*self.weight + w3*self.kakutei
    end
    return score
  end

  def clickBoard(canvas,text,x,y)
    #クリックされた座標(x,y)から盤の位置(x1,y1)を得る
    #ここにxの値からx1を計算するコードを書く
    x1 = (x-20)/70+1
    #ここにyの値からy1を計算するコードを書く
    y1 = (y-20)/70+1
    #座標を表示する(動作確認用)
    msg ="(x,y)=(" + x.to_s + "," + y.to_s + ") (x1,y1)=(" + x1.to_s + "," + y1.to_s + ")\n"
    text.insert("1.0",msg)

    #座標が盤の範囲外であれば何もせずreturn
    if !((1..BOARDSIZE).include? x1) or !((1..BOARDSIZE).include? y1)
      return
    end

    #石を打ってひっくり返す.打てないなら何もせずreturn
    if !self.move(x1,y1)
      return
    end

    #石を再描画
    self.drawAllDisks(canvas)
    Tk.update

    #ゲーム終了
    # if self.isGameOver
    #   score = self.numDisks
    #   # 多分バグってる
    #   if(score>0) and (@current_color=BLACK)
    #     text.insert("1.0",score.to_s+"枚差で黒の勝ちです\n")
    #   elsif(score>0) and (@current_color=WHITE)
    #     text.insert("1.0",score.to_s+"枚差で白の勝ちです\n")
    #   elsif(score<0) and (@current_color=BLACK)
    #     score = -score
    #     text.insert("1.0",score.to_s+"枚差で黒の勝ちです\n")
    #   elsif(score<0) and (@current_color=WHITE)
    #     score = -score
    #     text.insert("1.0",score.to_s+"枚差で白の勝ちです\n")
    #   elsif(score==0)
    #     text.insert("1.0","引き分けです\n")
    #   end
    # end

    #パスの場合は手番を入れ替えて@movableDirを更新
    if self.isPass
      @current_color = -@current_color
      self.initMovable
      text.insert("1.0","パス\n")
      return
    end

    #ゲーム終了か、人間が打てるようになるまでコンピュータの手を生成
    loop do
      maxScore = -MAXSCORE
      xmax = 0
      ymax = 0

      #全ての打てる手を生成し、それぞれの手をminmaxで探索
      for x in 1..BOARDSIZE do
        for y in 1..BOARDSIZE do
          if @movableDir[x][y]!=NONE
            #状態を保存
            tmpBoard = @rawBoard.map(&:dup)
            tmpDir = @movableDir.map(&:dup)
            tmpTurns = @turns
            tmpColor = @current_color

            self.move(x,y)
            #残り手数がLIMIT2以下の場合は、終盤とする(最後まで読み切る)
            if MAXTURNS - @turns <= LIMIT2
              mode = 1
              limit = LIMIT2

            elsif MAXTURNS - @turns <= LIMIT3
              mode = 2
              limit = LIMIT

            #そうでなければ、終盤でない(深さLIMITまで探索)
            else
              mode = 0
              limit = LIMIT
            end
            score = -alphabeta(limit-1,mode,-MAXSCORE,MAXSCORE)
            text.insert('1.0',"(x,y)=(" + x.to_s + "," + y.to_s + "), score = " + score.to_s + "\n")

            #元に戻す
            @rawBoard = tmpBoard.map(&:dup)
            @movableDir = tmpDir.map(&:dup)
            @turns = tmpTurns
            @current_color = tmpColor

            if maxScore < score
              maxScore = score
              xmax = x
              ymax = y
            end
          end
        end
      end
      self.move(xmax,ymax)
      self.drawAllDisks(canvas)
      text.insert('1.0',"選択されたのは (x,y)=(" + xmax.to_s + "," + ymax.to_s + "), score = " + maxScore.to_s + "\n")
      Tk.update

      #ゲーム終了ならループを抜ける
      if self.isGameOver
        score = self.numDisks
        if(score>0) and (@current_color=BLACK)
          text.insert("1.0",score.to_s+"枚差で黒の勝ちです\n")
        elsif(score>0) and (@current_color=WHITE)
          text.insert("1.0",score.to_s+"枚差で白の勝ちです\n")
        elsif(score<0) and (@current_color=BLACK)
          score = -score
          text.insert("1.0",score.to_s+"枚差で白の勝ちです\n")
        elsif(score<0) and (@current_color=WHITE)
          score = -score
          text.insert("1.0",score.to_s+"枚差で黒の勝ちです\n")
        elsif(score==0)
          text.insert("1.0","引き分けです\n")
        end
        break
      #人間がパスの場合、手番を入れ替える(ループは抜けない)
      elsif self.isPass
        @current_color = -@current_color
        self.initMovable
        text.insert('1.0',"パス\n")
      #そうでなければ、人間が打てるのでループを抜ける
      else
        break
      end
    end
  end
end

# Boardインスタンスの生成
board = Board.new

# 盤を初期化
board.init
# loopの実行（コメントは後で外す）
canvas = board.makeWindow
board.drawAllDisks(canvas)
Tk.mainloop
# board.loop