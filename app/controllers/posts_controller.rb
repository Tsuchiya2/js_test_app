class PostsController < ApplicationController
  #AWS Rekognition
  require 'aws-sdk-rekognition'

  def index
    @posts = Post.all.includes([:user, :greats]).order(created_at: :desc).page(params[:page]).per(10)
  end

  def new
    @post = Post.new
  end

  def create
    s3 = Aws::S3::Resource.new(
      region: 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    @post = current_user.posts.build(post_params)
  
    if @post.save
      image = @post.post_image
      if image.present?
        # アップロードされたファイルがある場合はS3にアップロードする
        file = image.file || image.cache_file
        obj = s3.bucket(ENV['AWS_S3_BUCKET_NAME']).object(image.filename)
        obj.upload_file(file.path, acl: 'public-read')
        
        # 画像に対してRekognitionを実行し、ラベル情報を取得する
        response = rekognition_client.detect_labels(
          image: {
            s3_object: {
              bucket: ENV['AWS_S3_BUCKET_NAME'],
              name: image.filename
            }
          }
        )
  
        # Rekognitionの結果に基づいて、投稿の可否を判断する
        if response.labels.any? { |label| label.name.downcase.include?('human') }
          @post.destroy
          flash[:alert] = '投稿が失敗しました。人間が写っています。'
          render :new
        else
          flash[:alert] = 'もふの投稿が成功しました！'
          redirect_to posts_path
        end
      else
        flash[:alert] = '投稿が失敗しました。画像を選択してください。'
        render :new
      end
    else
      flash[:alert] = '投稿が失敗しました。タイトルと本文は必須です。'
      render :new
    end
  end
  
  def show
    @post = Post.find(params[:id])
  end

  def greats
    @great_posts = current_user.great_posts.includes(:user).order(created_at: :desc)
  end 

  private

  def post_params
    params.require(:post).permit(:name, :body, :post_image, :post_image_cache)
  end

  def rekognition_tags(image, s3)
    # Rekognitionのクライアントを作成
    rekognition_client = Aws::Rekognition::Client.new(region: 'us-east-1', access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
    
    # 画像をS3にアップロード
    obj = s3.bucket(ENV['AWS_S3_BUCKET_NAME']).object(image.filename)
    obj.upload_file(image.tempfile, acl: 'public-read')

    # 画像に対してRekognitionを実行し、ラベル情報を取得する
    response = rekognition_client.detect_labels(
      image: {
        s3_object: {
          bucket: ENV['AWS_S3_BUCKET_NAME'],
          name: image.filename
        }
      },
      max_labels: 10
    )

    # ラベル情報からタグ名の配列を作成して返す
    response.labels.map(&:name)
  end
end